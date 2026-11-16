"""Confere os reportes do proc_saida contra um modelo em Python dos dois processadores.

Modelo (o mesmo calculo dos .cmm, em ponto flutuante de 32 bits):
  proc_entrada: y[n] = (x[n] + x[n-1] + x[n-2] + x[n-3]) / 4,  x = amostra / 32768,
                saida inteira = y * 10^6
  proc_saida  : a cada N = 256 amostras, [bloco, media*10^6, potencia media*10^6, max, min]

A conversao para inteiro e as somas no SAPHO nao sao identicas as do numpy ate o ultimo
bit, entao a comparacao usa tolerancia: +-2 unidades (micro-unidades) em todas as palavras,
ou 1e-5 relativo quando o valor e grande.

Entrada: a saida da simulacao (firmware/sim_io/saida.txt) ou o dados.csv da placa, em
que cada linha e um reporte (as NPAL primeiras colunas).

Uso:  python verificar.py <sinal_teste.txt> <saida.txt | dados.csv> [--laco]
      --laco: o ARM repetiu o arquivo de entrada em laco (dados da placa)
"""
import argparse
import sys
import numpy as np

N, NPAL = 256, 5


def modelo(x, n_reportes):
    xf = (x.astype(np.float32) / np.float32(32768.0)).astype(np.float32)
    xp = np.concatenate([np.zeros(3, np.float32), xf])
    y = np.float32(0.25) * (xp[3:] + xp[2:-1] + xp[1:-2] + xp[:-3])
    yi = np.trunc(y.astype(np.float64) * 1e6).astype(np.int64)        # fout(0, y*1e6)
    rep = []
    for b in range(n_reportes):
        blk = yi[b * N:(b + 1) * N]
        if len(blk) < N:
            break
        v = blk.astype(np.float64) / 1e6
        rep.append([b, v.mean() * 1e6, (v * v).mean() * 1e6, blk.max(), blk.min()])
    return np.array(rep)


def le_saida(caminho):
    linhas = []
    for ln in open(caminho):
        v = [int(c) for c in ln.strip().split(",") if c.strip()]
        if len(v) >= NPAL:
            linhas.append(v[:NPAL])
    return np.array(linhas, dtype=np.int64)


ap = argparse.ArgumentParser()
ap.add_argument("sinal")
ap.add_argument("saida")
ap.add_argument("--laco", action="store_true")
a = ap.parse_args()

x = np.loadtxt(a.sinal, dtype=np.int64)
med = le_saida(a.saida)
if len(med) == 0:
    sys.exit("nenhum reporte na saida")
b0 = int(med[0, 0])                                  # 1o bloco presente (a placa pode comecar depois)
if a.laco:
    reps = int(np.ceil((b0 + len(med)) * N / len(x))) + 1
    x = np.tile(x, reps)
ref = modelo(x, b0 + len(med))
ref = ref[b0:b0 + len(med)]
if len(ref) < len(med):                              # simulacao: o testbench segue entregando a
    print(f"(ignorados {len(med) - len(ref)} reportes depois do fim do arquivo)")   # ultima amostra
    med = med[:len(ref)]

ok = True
seq = np.all(np.diff(med[:, 0]) == 1)
print(f"{len(med)} reportes, blocos {med[0, 0]} a {med[-1, 0]}; indices consecutivos: {'sim' if seq else 'NAO'}")
ok &= bool(seq)
for i, nome in enumerate(["bloco", "media", "potencia", "maximo", "minimo"]):
    d = med[:len(ref), i] - ref[:, i]
    if i in (1, 2):
        tol = np.maximum(2.0, 1e-5 * np.abs(ref[:, i]))
        bom = np.abs(d) <= tol
        print(f"  {nome:9s}: maior diferenca {np.max(np.abs(d)):.1f} (tolerancia {tol.min():.0f} a {tol.max():.0f})")
    else:
        bom = np.abs(d) <= (0 if i == 0 else 2)
        print(f"  {nome:9s}: maior diferenca {int(np.max(np.abs(d)))}")
    ok &= bool(np.all(bom))
print("OK: os reportes batem com o modelo" if ok else "FALHOU: ha reportes fora da tolerancia")
sys.exit(0 if ok else 1)
