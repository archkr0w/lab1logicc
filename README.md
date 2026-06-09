<p align="center">
  <img src="frieren.jpg" width="450" alt="Frieren">
</p>

# Tarea 1 — Deducción Natural con LEX

**Lógica Computacional 22625** · Santiago de Chile, 15/5/2026

Un programa que recibe un *sequent* de lógica proposicional escrito en LaTeX y
construye **automáticamente** una demostración formal por Deducción Natural,
devolviéndola como una tabla LaTeX lista para compilar.

---

## 1. Qué hace

Entra un sequent (premisas, `\vdash`, conclusión) y sale la demostración
completa: cada línea numerada, con su justificación (qué regla se aplicó y
sobre qué líneas) y coloreada según el nivel de anidamiento de supuestos. Si no
encuentra demostración, imprime `% No se pudo demostrar.`

Por ejemplo, la entrada de `expresion3.txt`:

```latex
$$\mbox{\bf p} \rightarrow \mbox{\bf q} , \mbox{\bf p} \vdash \mbox{\bf q}$$
```

es el *modus ponens*: de `p -> q` y `p` se concluye `q`. El programa ve que `q`
es el consecuente de una implicación cuyo antecedente (`p`) ya está disponible,
aplica `->_e` y emite la tabla con las tres líneas.

---

## 2. Arquitectura

Todo vive en un solo `.lex` (lo pide la tarea), pero el grueso de la lógica está
en el bloque de C, no en las reglas léxicas. El flujo es de cuatro etapas:

```
LaTeX  ->  [1] Lexer (flex)        ->  tokens
       ->  [2] Parser              ->  fórmula en forma canónica prefija
       ->  [3] Motor de deducción  ->  tabla de líneas + justificaciones
       ->  [4] Impresión           ->  tabla LaTeX coloreada
```

El **lexer** convierte cada pedazo de LaTeX en un token entero:

| LaTeX          | Token        |
| -------------- | ------------ |
| `\mbox{\bf x}` | `TOK_VAR`    |
| `\neg`         | `TOK_NEG`    |
| `\wedge`       | `TOK_AND`    |
| `\rightarrow`  | `TOK_IMP`    |
| `\vdash`       | `TOK_VDASH`  |
| `( ) ,`        | paréntesis / coma |
| `$$`           | abre/cierra el sequent |

La global `dentro` asegura que solo se tokenice lo que está entre los dos `$$`.
Al cerrar el sequent se llama a `procesa()`, que dispara las etapas 2–4.

---

## 3. Representación interna de las fórmulas

La decisión de diseño clave: cada fórmula se guarda como un **string en notación
prefija**, con un carácter por nodo interno.

```c
/* prefijos canonicos para nodos internos de formula */
#define CNEG '0'   /* negacion    ->  0(A)   */
#define CAND '1'   /* conjuncion  ->  1(A,B) */
#define CIMP '2'   /* implicacion ->  2(A,B) */
```

Así, `p -> q` se guarda como `2(p,q)` y `~(p ^ q)` como `0(1(p,q))`.

¿Por qué esto importa? Porque toda la manipulación se vuelve manejo de strings
sobre arreglos de tamaño fijo — **sin punteros, sin árboles, sin liberar
memoria**:

- **Comparar** dos fórmulas = comparar dos strings (`sequ`).
- **Extraer** un subárbol = recorrer caracteres contando paréntesis (`get_sub`,
  que devuelve el primer o segundo argumento de un operador binario).
- **Imprimir** a LaTeX (`pflat`) = la operación inversa, reconstruyendo
  `\neg`, `\wedge`, `\rightarrow` y agregando paréntesis solo cuando la
  precedencia lo exige.

---

## 4. El parser: precedencia y asociatividad

Es un analizador de descenso recursivo. La parte elegante es cómo codifica la
asociatividad de cada operador en la *forma* de la función:

La conjunción asocia a la **izquierda** → se resuelve con un **bucle**:

```c
/* conjuncion asocia a la izquierda, se maneja con bucle */
void parse_conjunction(char *out) {
   char izq[FMAX], der[FMAX];
   parse_negation(izq);
   while (pos < ntokens && tokens[pos] == TOK_AND) {
      pos = pos + 1;
      parse_negation(der);
      make_bin(out, CAND, izq, der);
      scopy(izq, out);
   }
   scopy(out, izq);
}
```

La implicación asocia a la **derecha** → se resuelve con **recursión**:

```c
/* implicacion asocia a la derecha, se maneja con llamada recursiva */
void parse_implication(char *out) {
   char izq[FMAX], der[FMAX];
   parse_conjunction(izq);
   if (pos < ntokens && tokens[pos] == TOK_IMP) {
      pos = pos + 1;
      parse_implication(der);   /* <-- se llama a si misma para la derecha */
      make_bin(out, CIMP, izq, der);
   } else {
      scopy(out, izq);
   }
}
```

---

## 5. El motor de deducción (el corazón de la tarea)

La demostración se arma en una **tabla** (`tab[]`, `jus[]`, `niv[]`): cada fila
es una fórmula, su justificación y su nivel de anidamiento. Las premisas entran
en nivel 0; cada supuesto abre un nivel más. El motor combina dos estrategias.

### (A) Saturación hacia adelante

Aplica repetidamente, **hasta punto fijo**, todas las reglas de eliminación e
inferencia directa. Mientras se siga agregando algo nuevo, sigue iterando:

```c
/* satura la tabla aplicando todas las eliminaciones hacia adelante hasta punto fijo */
void satura(int nivel) {
   int ntab_antes, ntab_nuevo;
   ntab_antes = -1;
   ntab_nuevo = ntab;
   while (ntab_antes != ntab_nuevo) {
      ntab_antes = ntab_nuevo;
      extrae_and();            /* A^B   -> A, B            */
      extrae_neg();            /* ~~A   -> A               */
      expande_neg_imp(nivel);  /* ~(A->B) -> A, ~B         */
      adelante_and(nivel);     /* A, B  -> A^B   (^_i)     */
      adelante_imp(nivel);     /* A->B, A -> B   (->_e, MP)*/
      adelante_mt(nivel);      /* A->B, ~B -> ~A (MT)      */
      ntab_nuevo = ntab;
   }
}
```

Cada regla solo agrega lo que **aún no existe** en la tabla, lo que garantiza
que el punto fijo se alcanza y no hay bucles infinitos.

### (B) Búsqueda hacia atrás, dirigida por el objetivo

Para demostrar una meta `m`, `demuestra()` intenta en orden: (1) que ya esté en
la tabla, (2) derivarla por eliminación (`elimina`, que incluye *ex falso* y
modus ponens/tollens "al revés"), y si no, las **introducciones**.

La introducción de la implicación `->_i` es la más ilustrativa: para probar
`A -> B`, **supone** `A` (abre un nivel) y trata de demostrar `B`:

```c
/* ->_i: suponer antecedente, demostrar consecuente */
if (m[0] == CIMP) {
   sv = ntab;
   get_sub(ant, m, 0);
   get_sub(con, m, 1);
   ls = agrega(ant, "Supuesto", nivel + 1);
   lb = demuestra(con, nivel + 1, prof + 1);
   if (lb < 0) { ntab = sv; return -1; }   /* fallo: deshace el intento */
   build_jus(jbuf, "$\\rightarrow_i ~~ ", ls, "-", lb, "$");
   return agrega(m, jbuf, nivel);
}
```

Y la reducción al absurdo `~_i`: para probar `~A`, supone `A`, satura, y busca
una contradicción (alguna fórmula `B` junto con su `~B`):

```c
/* ~_i: suponer ant(m), saturar, buscar contradiccion B y ~B */
if (m[0] == CNEG) {
   sv = ntab;
   get_sub(ant, m, 0);
   ls2 = agrega(ant, "Supuesto", nivel + 1);
   satura(nivel + 1);
   k = 0; r2 = -1;
   while (k < ls2 && r2 < 0) {
      make_neg(negk, tab[k]);
      sv2 = ntab;
      r2 = elimina(negk, nivel + 1, prof + 1);
      if (r2 < 0) { ntab = sv2; k = k + 1; }
   }
   if (r2 > 0) {
      build_jus(jbuf, "$\\neg_i ~~ ", ls2, "-", r2, "$");
      return agrega(m, jbuf, nivel);
   }
   ntab = sv;
}
```

**Por qué las dos estrategias juntas:** la saturación hacia adelante resuelve
sola las cadenas de modus ponens/tollens; la búsqueda hacia atrás es la única
forma de decidir *cuándo* abrir un supuesto (`->_i`, `~_i`), que no se puede
adivinar mirando solo las premisas. Hay un límite de profundidad (`prof > 20`)
para cortar búsquedas que no convergen, y cada camino fallido restaura el tamaño
de la tabla (`ntab = sv`) para no dejar líneas basura.

---

## 6. Formato de salida

`imprime()` emite un `tabular` de tres columnas (línea, fórmula, justificación).
El nivel de anidamiento se traduce a color para visualizar los supuestos:

| Nivel | Color        |
| ----- | ------------ |
| 0     | sin color (premisas) |
| 1     | verde        |
| 2     | rojo         |
| 3+    | azul         |

Las justificaciones usan la notación estándar: `\rightarrow_e`,
`\rightarrow_i`, `\wedge_i`, `\wedge_{e1}`, `\wedge_{e2}`, `\neg\neg_e`,
`\neg_i`, `MT`, `\bot_e`, con los números de las líneas de las que se derivan.

---

## 7. Compilación

```sh
flex tarea1.lex
gcc -o tarea1.exe lex.yy.c -lfl
# si el sistema usa -ll en lugar de -lfl:
gcc -o tarea1.exe lex.yy.c -ll
```

`flex` genera `lex.yy.c` a partir de `tarea1.lex`; `gcc` lo compila enlazando la
librería de flex. Ninguno de los dos archivos generados se versiona.

## 8. Ejecución

```sh
./tarea1.exe < expresion.txt
```

El archivo de entrada contiene uno o más sequents en LaTeX, cada uno delimitado
por `$$ ... $$`. La salida es la demostración lista para pegar y compilar.

---

## 9. Casos de prueba

Cada ejemplo ejercita una parte distinta del motor:

| Archivo          | Sequent                          | Qué ejercita |
| ---------------- | -------------------------------- | ------------ |
| `expresion.txt`  | `q->r, ~q->~p \|- p->r`          | Contrapositiva: abrir supuesto `p` (`->_i`) + modus tollens + ponens |
| `expresion2.txt` | `q->r \|- (~q->~p) -> (p->r)`    | Implicación anidada → abre **dos** supuestos |
| `expresion3.txt` | `p->q, p \|- q`                  | Modus ponens puro (`->_e`), el caso mínimo |
| `expresion4.txt` | `p, q \|- p^q`                   | Introducción de la conjunción (`^_i`) |
| `expresion5.txt` | `p->q, p->~q \|- ~p`             | Reducción al absurdo (`~_i`) |
| `expresion6.txt` | `\|- (~q->~p) -> (p->q)`         | Teorema sin premisas: supuestos + doble negación + absurdo |

---

## 10. Archivos del proyecto

Versionados:

| Archivo | Descripción |
| ------- | ----------- |
| `tarea1.lex` | código fuente (lexer + motor en C) |
| `expresion.txt` … `expresion6.txt` | casos de prueba |
| `README.md` | este archivo |
| `frieren.jpg` | imagen de portada |
| `.gitignore` | define qué no se versiona |

No se versionan: el informe (`informe.tex`, `informe.pdf`), el logo
(`Logo-2016.png`) ni los archivos generados por la compilación (`lex.yy.c`,
`tarea1.exe`).

---

## 11. Limitaciones conocidas

- Solo se manejan **negación** (`~`), **conjunción** (`^`) e **implicación**
  (`->`). No hay disyunción ni bicondicional.
- Los tamaños son fijos (`MAX` líneas, `FMAX` caracteres por fórmula). Subir
  `MAX` exige cuidado: `tab[]` y `jus[]` son arreglos grandes y varias funciones
  usan buffers locales, así que un `MAX` muy alto puede desbordar la pila.
- La búsqueda tiene un límite de profundidad (20). Demostraciones que necesiten
  anidar más supuestos que eso no se encontrarán.
