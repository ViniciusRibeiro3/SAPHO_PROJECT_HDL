"""Roda o projeto na placa e traz os reportes.

Envia o programa do ARM e o arquivo de sinal para a placa (scp), roda o programa (ssh),
traz o dados.csv de volta e confere os reportes contra o modelo (verificar.py).
O FPGA tem de estar gravado antes (ver README: quartus_pgm).

Precisa de ssh/scp no PATH (o OpenSSH do Windows serve) e de acesso como root a placa.

Uso:  python capturar.py <IP da placa> [--sinal sinal_teste.txt] [--reportes 600] [--sem-verificar]
"""
import argparse
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
SSH = ["-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=10"]

ap = argparse.ArgumentParser()
ap.add_argument("ip")
ap.add_argument("--sinal", default=str(RAIZ / "firmware" / "sim_io" / "sinal_teste.txt"))
ap.add_argument("--reportes", type=int, default=600)
ap.add_argument("--programa", default=str(RAIZ / "binarios" / "sapho_arm"))
ap.add_argument("--saida", default=str(RAIZ / "resultados"))
ap.add_argument("--sem-verificar", action="store_true")
a = ap.parse_args()

sinal = Path(a.sinal)
if not sinal.exists():
    subprocess.run([sys.executable, str(RAIZ / "python" / "gerar_sinal.py"), str(sinal)], check=True)
alvo = f"root@{a.ip}"
subprocess.run(["scp", *SSH, a.programa, f"{alvo}:/home/root/sapho_arm"], check=True)
subprocess.run(["scp", *SSH, str(sinal), f"{alvo}:/home/root/sinal_arm.txt"], check=True)
r = subprocess.run(["ssh", *SSH, alvo, f"cd /home/root && chmod +x sapho_arm && ./sapho_arm {a.reportes} 1"],
                   capture_output=True, text=True)
print(r.stdout)
if r.returncode:
    sys.exit(f"o programa falhou na placa:\n{r.stderr}")
saida = Path(a.saida)
saida.mkdir(parents=True, exist_ok=True)
subprocess.run(["scp", *SSH, f"{alvo}:/home/root/dados.csv", str(saida / "dados.csv")], check=True)
print(f"-> {saida / 'dados.csv'}")
if not a.sem_verificar:
    sys.exit(subprocess.run([sys.executable, str(RAIZ / "python" / "verificar.py"), str(sinal),
                             str(saida / "dados.csv"), "--laco"]).returncode)
