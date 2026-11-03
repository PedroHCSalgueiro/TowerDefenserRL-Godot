# Início mais lento: preços, ouro e cópias por estrela

Medição de 02/11/2026 sobre o commit `4593ed4`, no conjunto Valcoroa + Costa Rubra (16 heróis), no mapa que cresce e com os bots
sequential e good. Foram 18 seeds por bot em cada variante, as mesmas em todas. As variantes entraram pelo playtest
(`--prices`, `--bonus` e `--copies` em `dev/playtest.gd`).

**Decisão do Pedro (02/11/2026):** a variante C virou a regra dos heróis (`data/sets/heroes/economy.json` e
`copiesPerStar` em `data/sets/heroes/towers.json`). Com isso, a variante "A, hoje" abaixo é a regra antiga.

| Variante | O que muda |
| --- | --- |
| A, hoje | preços 10/15/25/40, renda de fim de onda `8 + 2 × onda`, 2 cópias por estrela |
| B, preços e ouro | preços 10/20/30/50 e renda `3 + 1 × onda` |
| C, B com 3 cópias | B, com 3 cópias por estrela (★3 = 9 cópias) |
| D, só 3 cópias | regras de hoje, com 3 cópias por estrela |

## Conclusão

- **Com 16 heróis, os bots já não fazem ★3 cedo.** Hoje a primeira ★3 sai na onda 6 (sequential) e 7 (good), porque as
  compras se espalham por vários heróis. A ★3 na onda 3 da conta simplificada só acontece comprando um herói só.
- **Preço e ouro sozinhos (B) mudam pouco:** a ★3 atrasa 1 onda, e a run termina 1,6 onda antes no sequential e 0,7 no good.
  O good guarda ouro para os juros, e eles compensam parte da renda menor.
- **3 cópias por estrela é a alavanca forte.** Com B (variante C), a primeira ★2 vai da onda 2 para a 4, a ★3 vai para a
  16–21 e só aparece em 10 a 11 das 18 runs. A run termina 3,1 ondas antes no sequential e 2,1 no good.
- **Nenhuma variante faz perder cedo.** A derrota continua entre as ondas 25 e 27, e a run de bot continua com 39 a 55
  minutos. Para perder perto da onda 10–15, a economia não basta: é preciso mexer na força das ondas do início.

## Resultados

"Morte ≤ 3" são as runs perdidas até a onda 3. Elas vêm do bot, que às vezes só compra o Irmão Tomás (sem dano), e ficam
fora da onda final e dos minutos. Os minutos contam só a onda rodando, sem as pausas de loja.

| Variante | Bot | Morte ≤ 3 | Onda final (p10–p90) | Núcleo < 50% | 1ª ★2 | 1ª ★3 (runs com ★3) | Torres na onda 10 | Minutos |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A, hoje | sequential | 3 | 28 (26–29) | 27 | 2 | 6 (15/18) | 8 | 48 |
| B, preços e ouro | sequential | 3 | 26 (25–27) | 25 | 2 | 7 (15/18) | 6 | 45 |
| C, B com 3 cópias | sequential | 3 | 25 (23–27) | 25 | 4 | 16 (10/18) | 6 | 39 |
| D, só 3 cópias | sequential | 3 | 26 (25–27) | 25 | 3 | 13 (14/18) | 6 | 48 |
| A, hoje | good | 0 | 27,5 (26–30) | 25,5 | 2,5 | 7 (18/18) | 6 | 57 |
| B, preços e ouro | good | 1 | 27 (25–28) | 25 | 3 | 8 (17/18) | 5 | 53 |
| C, B com 3 cópias | good | 1 | 26 (24–26) | 24 | 4 | 21 (11/18) | 5 | 49 |
| D, só 3 cópias | good | 0 | 27 (25–29) | 25 | 3 | 15 (15/18) | 6 | 55 |

**Diferença na mesma seed (variante menos hoje, em ondas):**

| Bot | B | C | D |
| --- | --- | --- | --- |
| sequential | −1,6 ± 0,4 | −3,1 ± 0,5 | −1,2 ± 0,3 |
| good | −0,7 ± 0,3 | −2,1 ± 0,4 | −0,8 ± 0,2 |

Nenhum bot venceu as 40 ondas em nenhuma variante.

## Como repetir

```
godot --headless --path . -s dev/playtest.gd -- --set=valcoroa_costarubra --policy=good --from=0 --count=6 --prices=10,20,30,50 --bonus=3:1 --copies=3 --out=arquivo.json
```

As opções sobrescrevem os dados só naquele processo. `--copies` troca o `copiesPerStar` das torres; para medir a regra
antiga dos heróis, use `--prices=10,15,25,40 --bonus=8:2 --copies=2`.
