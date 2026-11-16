"""Gera o sinal de teste: um inteiro de 16 bits por linha.

Padrao: 60 Hz com 3a harmonica de 20% e um pouco de ruido, amostrado a 15 360 Hz,
16 384 amostras (64 ciclos exatos de 60 Hz: o ARM pode repetir o arquivo em laco sem
descontinuidade). Pico de 30 000 (cabe nos 16 bits com folga).

Uso:  python gerar_sinal.py [saida.txt] [--amostras N] [--freq F]
"""
import argparse
import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("saida", nargs="?", default="sinal_teste.txt")
ap.add_argument("--amostras", type=int, default=16384)
ap.add_argument("--freq", type=float, default=60.0)
ap.add_argument("--fs", type=float, default=15360.0)
a = ap.parse_args()

n = np.arange(a.amostras)
t = n / a.fs
x = np.cos(2 * np.pi * a.freq * t) + 0.2 * np.cos(2 * np.pi * 3 * a.freq * t)
x += 0.01 * np.random.default_rng(1).standard_normal(a.amostras)
x = np.round(30000 * x / np.max(np.abs(x))).astype(np.int64)
np.savetxt(a.saida, x, fmt="%d")
print(f"{a.saida}: {a.amostras} amostras, pico {np.abs(x).max()}")
