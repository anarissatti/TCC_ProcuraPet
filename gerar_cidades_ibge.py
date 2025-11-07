# -*- coding: utf-8 -*-
"""
Gera assets/data/cidades_por_uf.json a partir da API do IBGE.
Requisitos: Python 3.8+, requests (pip install requests)
"""
import json
import os
import sys
from collections import defaultdict

import requests

UFs = [
    "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS","MT",
    "PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC","SE","SP","TO"
]

def fetch_municipios_por_uf(uf: str):
    url = f"https://servicodados.ibge.gov.br/api/v1/localidades/estados/{uf}/municipios"
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    data = r.json()
    # Cada item tem "nome", e várias infos; usamos só o nome
    return [m["nome"] for m in data]

def main():
    saida_dir = os.path.join("assets", "data")
    os.makedirs(saida_dir, exist_ok=True)
    saida_arq = os.path.join(saida_dir, "cidades_por_uf.json")

    mapa = defaultdict(list)
    total = 0

    for uf in UFs:
        print(f"Baixando municípios de {uf}…")
        cidades = fetch_municipios_por_uf(uf)
        cidades_ordenadas = sorted(cidades, key=lambda s: s.lower())
        mapa[uf] = cidades_ordenadas
        total += len(cidades_ordenadas)

    with open(saida_arq, "w", encoding="utf-8") as f:
        json.dump(mapa, f, ensure_ascii=False, indent=2)

    print(f"\nOK! Gerado {saida_arq}")
    print(f"UFs: {len(UFs)} | Cidades: {total}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("Erro:", e)
        sys.exit(1)
