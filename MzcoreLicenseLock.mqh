//+------------------------------------------------------------------+
//| MzcoreLicenseLock.mqh - Account lock via GitHub JSON (WebRequest) |
//+------------------------------------------------------------------+
#ifndef __MZCORE_LICENSE_LOCK_MQH__
#define __MZCORE_LICENSE_LOCK_MQH__

extern bool   UseLicenseLock        = true;
extern string License_JSON_URL        = "https://raw.githubusercontent.com/Zikri123123/core2026SNR/main/licenses.json";
extern int    License_CheckTimeout    = 8000;
extern int    License_RecheckMins     = 60;

bool     g_license_ok = false;
string   g_license_message = "Belum disahkan";
datetime g_last_license_check = 0;

string LicenseTrim(const string text)
{
   string s = text;
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

bool LicenseEqualsExact(const string a, const string b)
{
   return (StringCompare(LicenseTrim(a), LicenseTrim(b), true) == 0);
}

bool GetObjectChunkFromKeyPos(const string response, const int keyPos, string &chunkOut)
{
   int objStart = keyPos;
   while(objStart >= 0 && StringGetCharacter(response, objStart) != '{')
      objStart--;

   if(objStart < 0)
      return false;

   int depth = 0;
   int len = StringLen(response);
   for(int i = objStart; i < len; i++)
   {
      int ch = StringGetCharacter(response, i);
      if(ch == '{')
         depth++;
      else if(ch == '}')
      {
         depth--;
         if(depth == 0)
         {
            chunkOut = StringSubstr(response, objStart, i - objStart + 1);
            return true;
         }
      }
   }

   return false;
}

bool ChunkHasInactiveFlag(const string chunk)
{
   if(StringFind(chunk, "\"active\":false") >= 0) return true;
   if(StringFind(chunk, "\"active\": false") >= 0) return true;
   return false;
}

bool IsExpired(const string chunk)
{
   int expKey = StringFind(chunk, "\"expires\":");
   if(expKey < 0) return false;

   int q1 = StringFind(chunk, "\"", expKey + 10);
   if(q1 < 0) return false;
   int q2 = StringFind(chunk, "\"", q1 + 1);
   if(q2 <= q1) return false;

   string expDate = StringSubstr(chunk, q1 + 1, q2 - q1 - 1);
   expDate = LicenseTrim(expDate);
   if(StringLen(expDate) == 0) return false;

   datetime expiry = StringToTime(expDate + " 23:59:59");
   if(expiry <= 0) return false;
   return (TimeCurrent() > expiry);
}

string ExtractOwner(const string chunk)
{
   int ownerKey = StringFind(chunk, "\"owner\":");
   if(ownerKey < 0) return "";

   int q1 = StringFind(chunk, "\"", ownerKey + 8);
   if(q1 < 0) return "";
   int q2 = StringFind(chunk, "\"", q1 + 1);
   if(q2 <= q1) return "";

   return StringSubstr(chunk, q1 + 1, q2 - q1 - 1);
}

bool FindAccountChunk(const string response, const int account, string &chunkOut)
{
   string acc = IntegerToString(account);
   string patterns[2];
   patterns[0] = "\"account\":" + acc;
   patterns[1] = "\"account\": " + acc;

   int pos = -1;
   for(int i = 0; i < 2; i++)
   {
      pos = StringFind(response, patterns[i]);
      if(pos >= 0) break;
   }
   if(pos < 0) return false;

   return GetObjectChunkFromKeyPos(response, pos, chunkOut);
}

bool FindOwnerChunk(const string response, const string ownerName, string &chunkOut)
{
   string targetName = LicenseTrim(ownerName);
   if(StringLen(targetName) == 0) return false;

   int searchPos = 0;
   while(true)
   {
      int ownerKey = StringFind(response, "\"owner\":", searchPos);
      if(ownerKey < 0) break;

      string chunk = "";
      if(GetObjectChunkFromKeyPos(response, ownerKey, chunk))
      {
         string listedOwner = ExtractOwner(chunk);
         if(LicenseEqualsExact(listedOwner, targetName))
         {
            chunkOut = chunk;
            return true;
         }
      }

      searchPos = ownerKey + 8;
   }

   return false;
}

bool ParseGitHubLicense(const string response, const int account, string &messageOut)
{
   string chunk = "";
   bool matchedByAccount = FindAccountChunk(response, account, chunk);
   bool matchedByName = false;

   if(!matchedByAccount)
      matchedByName = FindOwnerChunk(response, AccountName(), chunk);

   if(!matchedByAccount && !matchedByName)
   {
      messageOut = "Akaun MT4 belum didaftarkan dalam GitHub.";
      return false;
   }

   if(ChunkHasInactiveFlag(chunk))
   {
      messageOut = "Akaun MT4 dinyahaktifkan.";
      return false;
   }

   if(IsExpired(chunk))
   {
      messageOut = "Lesen akaun MT4 sudah tamat tempoh.";
      return false;
   }

   string owner = ExtractOwner(chunk);
   if(StringLen(LicenseTrim(owner)) > 0)
      messageOut = "Lesen sah untuk " + owner + ".";
   else if(matchedByAccount)
      messageOut = "Lesen sah untuk akaun " + IntegerToString(account) + ".";
   else
      messageOut = "Lesen sah.";

   return true;
}

bool ValidateLicense(bool forceCheck = false)
{
   if(!UseLicenseLock)
   {
      g_license_ok = true;
      g_license_message = "License lock dimatikan";
      return true;
   }

   if(!forceCheck && g_license_ok)
   {
      int mins = (int)((TimeCurrent() - g_last_license_check) / 60);
      if(mins < License_RecheckMins)
         return true;
   }

   string url = License_JSON_URL;
   char data[];
   char result[];
   string result_headers;

   ResetLastError();
   int res = WebRequest("GET", url, NULL, NULL, License_CheckTimeout, data, 0, result, result_headers);

   if(res == -1)
   {
      int err = GetLastError();
      g_license_ok = false;
      g_license_message = "Gagal baca senarai lesen GitHub. Error " + IntegerToString(err);
      Print("LICENSE: WebRequest gagal. Error=", err);
      if(err == 4060)
         Print("LICENSE: Tambah URL ini dalam MT4 WebRequest whitelist: https://raw.githubusercontent.com");
      return false;
   }

   if(res != 200)
   {
      g_license_ok = false;
      g_license_message = "GitHub JSON error HTTP " + IntegerToString(res);
      Print("LICENSE: HTTP ", res, " | ", CharArrayToString(result));
      return false;
   }

   string response = CharArrayToString(result);
   string msg = "";
   g_license_ok = ParseGitHubLicense(response, AccountNumber(), msg);
   g_license_message = msg;
   g_last_license_check = TimeCurrent();

   if(g_license_ok)
      Print("LICENSE: OK | Akaun ", AccountNumber(), " | ", g_license_message);
   else
      Print("LICENSE: BLOCKED | Akaun ", AccountNumber(), " | ", g_license_message);

   return g_license_ok;
}

void ShowLicenseStatusOnChart()
{
   if(!UseLicenseLock) return;
   string status = g_license_ok ? "LICENSE: OK" : "LICENSE: BLOCKED";
   Comment(status, "\n", g_license_message, "\nAkaun: ", AccountNumber());
}

#endif
