import os

api_path = r"C:\Users\molotov\.gemini\antigravity\scratch\akremjobhunter\mobile\lib\services\api_service.dart"
with open(api_path, "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace(
    "static String serverUrl = 'http://10.0.2.2:8000';",
    "static const String defaultCloudUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://akremjobhunter-backend.onrender.com');\n  static String serverUrl = defaultCloudUrl;"
)

code = code.replace(
    "serverUrl = prefs.getString(_keyServerUrl) ?? 'http://10.0.2.2:8000';",
    "final saved = prefs.getString(_keyServerUrl);\n    if (saved != null && saved.isNotEmpty && !saved.contains('10.0.2.2') && !saved.contains('127.0.0.1') && !saved.contains('192.168.')) {\n      serverUrl = saved;\n    } else {\n      serverUrl = defaultCloudUrl;\n    }"
)

with open(api_path, "w", encoding="utf-8") as f:
    f.write(code)

auth_path = r"C:\Users\molotov\.gemini\antigravity\scratch\akremjobhunter\mobile\lib\screens\auth_screen.dart"
with open(auth_path, "r", encoding="utf-8") as f:
    auth_code = f.read()

auth_code = auth_code.replace("http://192.168.1.9:8000", "https://akremjobhunter-backend.onrender.com")
with open(auth_path, "w", encoding="utf-8") as f:
    f.write(auth_code)

print("Updated api_service.dart and auth_screen.dart cleanly")
