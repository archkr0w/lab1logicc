# CLAUDE.md — Tarea 1: Deducción Natural
## Lógica Computacional 22625 · Universidad de Santiago de Chile

---

## Compilar y ejecutar

```bash
flex tarea1.lex && gcc -o tarea1.exe lex.yy.c -ll
./tarea1.exe < expresion.txt
```

El warning de macOS sobre versión es inofensivo. Nunca usar `-o tarea1.lex` (sobrescribe el fuente).

---

## Descripción

Demostrador de deducción natural para lógica proposicional. Lee sequents en LaTeX delimitados por `$$` y genera la demostración completa en LaTeX.

**Operadores:** `\neg` (¬), `\wedge` (∧), `\rightarrow` (→)

**Entrada:** `$$premisa_1, ..., premisa_n \vdash conclusion$$`

**Salida:** bloque `tabular` LaTeX con numeración, fórmulas y justificaciones coloreadas.

---

## Arquitectura (único archivo `tarea1.lex`)

```
Sección C (%{ %})
  nf, eq, itos          — árbol de fórmulas y utilidades
  agrega, agrj, busca   — tabla de demostración
  pflat                 — impresión LaTeX de fórmulas
  aplica, apnegs, pushop, cierra, fin  — parser shunting-yard
  elimina               — reglas de eliminación (backward chaining)
  demuestra             — motor principal (backward chaining)
  imprime               — salida LaTeX

Definiciones LEX
  letra, variable, esp, neg, conj, impl, vdash, mbox, delim

Reglas LEX
  $$ → iniciar/procesar sequent
  \mbox{\bf X} → variable proposicional
  \neg, \wedge, \rightarrow, \vdash, (, ), , → tokens

main()
```

---

## Reglas de inferencia implementadas

| Regla | Descripción |
|---|---|
| →_e | Modus ponens: A→B y A dan B |
| →_i | Intro implicación: suponer A, demostrar B, concluir A→B |
| ¬¬_e | Elim doble negación: ¬¬A da A |
| ¬¬_i | Intro doble negación: A da ¬¬A |
| MT | Modus tollens: A→B y ¬B dan ¬A |
| ∧_e1/e2 | Elim conjunción: A∧B da A o B |
| ∧_i | Intro conjunción: A y B dan A∧B |
| ¬_i | Reducción al absurdo: asumir A, derivar contradicción, concluir ¬A |

---

## Colores en la salida

| Nivel | Color | Caso |
|---|---|---|
| 0 + Premisa | negro | premisas del sequent |
| 0 + derivada | azul | conclusión final demostrada |
| 1 | verde | primer supuesto |
| 2 | rojo | segundo supuesto anidado |
| 3+ | azul | supuestos más profundos |

---

## Normas del profesor (aplicadas)

- Sin `++`/`--` → usar `i = i + 1`
- Sin `strcmp`, `sprintf`, `strlen`, `strcat` → funciones propias (`eq`, `itos`, `agrj`)
- Sin `free` → solo `calloc`
- Solo palabras reservadas: `include define void int char unsigned if while for return main struct NULL printf calloc`
- Sangría 3 espacios, comentario de bloque en cada función, variables al inicio

---

## Ejemplo

**Entrada:**
```
$$\mbox{\bf q} \rightarrow \mbox{\bf r} \vdash
  (\neg \mbox{\bf q} \rightarrow \neg \mbox{\bf p})
  \rightarrow (\mbox{\bf p} \rightarrow \mbox{\bf r})$$
```

**Demostración generada (9 líneas):**

| N | Fórmula | Justificación |
|---|---|---|
| 1 | q→r | Premisa |
| 2 | ¬q→¬p | Supuesto |
| 3 | p | Supuesto |
| 4 | ¬¬p | ¬¬_i 3 |
| 5 | ¬¬q | MT 2, 4 |
| 6 | q | ¬¬_e 5 |
| 7 | r | →_e 1, 6 |
| 8 | p→r | →_i 3-7 |
| 9 | (¬q→¬p)→(p→r) | →_i 2-8 |
