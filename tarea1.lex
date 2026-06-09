%{
/* Deduccion natural
   Autores: Nicolas Maldonado - Felipe Ugalde
   Santiago de Chile, 15/5/2026
*/
#include <stdio.h>
#include <stdlib.h>

/* limites de los arreglos - si se sube MAX hay que tener cuidado
   con la pila porque tab y jus son locales en procesa() */
#define MAX   128
#define FMAX  256
#define NMAX  32

/* tipos de simbolo, numerados desde 0 */
#define TOK_VAR    0
#define TOK_NEG    1
#define TOK_AND    2
#define TOK_IMP    3
#define TOK_VDASH  4
#define TOK_LPAREN 5
#define TOK_RPAREN 6
#define TOK_COMMA  7

/* prefijos canonicos para nodos internos de formula */
#define CNEG '0'
#define CAND '1'
#define CIMP '2'

/* variables globales */
int  tokens[MAX];
char tokvar[MAX][NMAX];
int  ntokens;
int  pos;

char tab[MAX][FMAX];
char jus[MAX][FMAX];
int  niv[MAX];
int  ntab;

int  dentro;

/* compara a y b caracter a caracter, retorna 1 si son iguales */
int sequ(char *a, char *b) {
   int i;
   i = 0;
   while (a[i] && b[i] && a[i] == b[i]) i = i + 1;
   return (a[i] == b[i]);
}

/* copia src en dst */
void scopy(char *dst, char *src) {
   int i;
   i = 0;
   while (src[i]) {
      dst[i] = src[i];
      i = i + 1;
   }
   dst[i] = '\0';
}

/* construye la negacion de a en out: resultado es CNEG(a) */
void make_neg(char *out, char *a) {
   int i, j;
   i = 0;
   j = 0;
   out[i] = CNEG;
   i = i + 1;
   out[i] = '(';
   i = i + 1;
   while (a[j]) {
      out[i] = a[j];
      i = i + 1;
      j = j + 1;
   }
   out[i] = ')';
   i = i + 1;
   out[i] = '\0';
}

/* construye op(a,b) en out para operadores binarios */
void make_bin(char *out, char op, char *a, char *b) {
   int i, j;
   i = 0;
   j = 0;
   out[i] = op;
   i = i + 1;
   out[i] = '(';
   i = i + 1;
   while (a[j]) {
      out[i] = a[j];
      i = i + 1;
      j = j + 1;
   }
   out[i] = ',';
   i = i + 1;
   j = 0;
   while (b[j]) {
      out[i] = b[j];
      i = i + 1;
      j = j + 1;
   }
   out[i] = ')';
   i = i + 1;
   out[i] = '\0';
}

/* saca el n-esimo argumento de una formula prefija.
   cual=0 primer argumento, cual=1 segundo argumento.
   hay que contar parentesis para no confundirse con formulas anidadas */
void get_sub(char *out, char *f, int cual) {
   int i, j, prof_par, hallado;
   i = 2;
   j = 0;
   prof_par = 0;
   hallado = 0;
   while (f[i] && !(f[i] == ')' && prof_par == 0)) {
      if (f[i] == ',' && prof_par == 0) {
         hallado = 1;
         i = i + 1;
      } else {
         if (f[i] == '(') prof_par = prof_par + 1;
         if (f[i] == ')') prof_par = prof_par - 1;
         if (cual == 0 && hallado == 0) {
            out[j] = f[i];
            j = j + 1;
         } else if (cual == 1 && hallado == 1) {
            out[j] = f[i];
            j = j + 1;
         }
         i = i + 1;
      }
   }
   out[j] = '\0';
}

/* agrega una linea a la tabla, retorna numero de linea (base 1) o -1 si llena */
int agrega(char *f, char *j, int nivel) {
   int i;
   if (ntab > MAX - 1) return -1;
   i = 0;
   while (f[i] && i < FMAX - 1) {
      tab[ntab][i] = f[i];
      i = i + 1;
   }
   tab[ntab][i] = '\0';
   i = 0;
   while (j[i] && i < FMAX - 1) {
      jus[ntab][i] = j[i];
      i = i + 1;
   }
   jus[ntab][i] = '\0';
   niv[ntab] = nivel;
   ntab = ntab + 1;
   return ntab;
}

/* busca f en las primeras lim lineas de tabla, retorna numero de linea o -1 */
int busca(char *f, int lim) {
   int i;
   i = 0;
   while (i < lim && i < ntab) {
      if (sequ(tab[i], f)) return i + 1;
      i = i + 1;
   }
   return -1;
}

/* arma el string de justificacion: pre + numero_a + sep + numero_b + suf.
   cualquier puntero puede ser NULL si no aplica para esa justificacion */
void build_jus(char *out, char *pre, int a, char *sep, int b, char *suf) {
   char na[8], nb[8];
   int i, k, n;
   k = 0;
   i = 0;
   if (pre) {
      while (pre[i] && k < FMAX - 1) {
         out[k] = pre[i];
         k = k + 1;
         i = i + 1;
      }
   }
   if (a > 0) {
      n = a;
      i = 0;
      while (n > 0) {
         na[i] = '0' + (n % 10);
         i = i + 1;
         n = n / 10;
      }
      n = i;
      while (n > 0) {
         n = n - 1;
         out[k] = na[n];
         k = k + 1;
      }
   }
   if (sep) {
      i = 0;
      while (sep[i] && k < FMAX - 1) {
         out[k] = sep[i];
         k = k + 1;
         i = i + 1;
      }
   }
   if (b > 0) {
      n = b;
      i = 0;
      while (n > 0) {
         nb[i] = '0' + (n % 10);
         i = i + 1;
         n = n / 10;
      }
      n = i;
      while (n > 0) {
         n = n - 1;
         out[k] = nb[n];
         k = k + 1;
      }
   }
   if (suf) {
      i = 0;
      while (suf[i] && k < FMAX - 1) {
         out[k] = suf[i];
         k = k + 1;
         i = i + 1;
      }
   }
   out[k] = '\0';
}

/* imprime una formula canonica en LaTeX de forma recursiva */
void pflat(char *f) {
   char l[FMAX], r[FMAX];
   if (f == NULL) return;
   if (f[0] == '\0') return;
   if (f[0] == CNEG) {
      get_sub(l, f, 0);
      printf("\\neg ");
      /* parentesis si el interior es binario */
      if (l[0] == CIMP || l[0] == CAND) {
         printf("(");
         pflat(l);
         printf(")");
      } else {
         pflat(l);
      }
      return;
   }
   if (f[0] == CAND || f[0] == CIMP) {
      get_sub(l, f, 0);
      get_sub(r, f, 1);
      /* lado izquierdo con parentesis si es implicacion
         porque -> asocia a la derecha */
      if (l[0] == CIMP) {
         printf("(");
         pflat(l);
         printf(")");
      } else {
         pflat(l);
      }
      if (f[0] == CAND) printf(" \\wedge ");
      else              printf(" \\rightarrow ");
      if (r[0] == CIMP) {
         printf("(");
         pflat(r);
         printf(")");
      } else {
         pflat(r);
      }
      return;
   }
   /* si llegamos aca es una variable proposicional */
   printf("\\mbox{\\bf %s}", f);
}

/* imprime la tabla de demostracion completa como tabular LaTeX con colores */
void imprime(void) {
   int i;
   char *col;
   printf("{\\tiny\n\\begin{tabular}{r l l}\n");
   i = 0;
   while (i < ntab) {
      /* nivel 0 sin color para premisas, 1=verde, 2=rojo, resto=azul */
      if (niv[i] == 1)      col = "green";
      else if (niv[i] == 2) col = "red";
      else                  col = "blue";
      if (niv[i] == 0 && jus[i][0] == 'P') {
         printf("%d & $", i + 1);
         pflat(tab[i]);
         printf("$ & %s \\\\ \\\\\n", jus[i]);
      } else {
         printf("{\\color{%s} %d} & {\\color{%s} $", col, i + 1, col);
         pflat(tab[i]);
         printf("$} & {\\color{%s} %s} \\\\ \\\\\n", col, jus[i]);
      }
      i = i + 1;
   }
   printf("\\end{tabular}\n}\n\n");
}

/* analizador de descenso recursivo.
   precedencia de menor a mayor: implicacion, conjuncion, negacion, atomo */
void parse_formula(char *out);

void parse_atom(char *out) {
   char interno[FMAX];
   if (pos < ntokens && tokens[pos] == TOK_LPAREN) {
      pos = pos + 1;
      parse_formula(interno);
      if (pos < ntokens && tokens[pos] == TOK_RPAREN) pos = pos + 1;
      scopy(out, interno);
   } else if (pos < ntokens && tokens[pos] == TOK_VAR) {
      scopy(out, tokvar[pos]);
      pos = pos + 1;
   } else {
      out[0] = '\0';
   }
}

void parse_negation(char *out) {
   char interno[FMAX];
   if (pos < ntokens && tokens[pos] == TOK_NEG) {
      pos = pos + 1;
      parse_negation(interno);
      make_neg(out, interno);
   } else {
      parse_atom(out);
   }
}

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

/* implicacion asocia a la derecha, se maneja con llamada recursiva */
void parse_implication(char *out) {
   char izq[FMAX], der[FMAX];
   parse_conjunction(izq);
   if (pos < ntokens && tokens[pos] == TOK_IMP) {
      pos = pos + 1;
      parse_implication(der);
      make_bin(out, CIMP, izq, der);
   } else {
      scopy(out, izq);
   }
}

void parse_formula(char *out) {
   parse_implication(out);
}

/* extrae A y B de toda conjuncion A^B que este en tabla.
   hereda el nivel de la conjuncion para que el color quede bien.
   itera hasta que no haya nada nuevo que agregar */
void extrae_and(void) {
   char ant[FMAX], con[FMAX], jbuf[FMAX];
   int i, cambio, lim;
   cambio = 1;
   while (cambio == 1) {
      cambio = 0;
      lim = ntab;
      i = 0;
      while (i < lim) {
         if (tab[i][0] == CAND) {
            get_sub(ant, tab[i], 0);
            get_sub(con, tab[i], 1);
            if (busca(ant, ntab) < 0) {
               build_jus(jbuf, "$\\wedge_{e1} ~~ ", i + 1, NULL, 0, "$");
               agrega(ant, jbuf, niv[i]);
               cambio = 1;
            }
            if (busca(con, ntab) < 0) {
               build_jus(jbuf, "$\\wedge_{e2} ~~ ", i + 1, NULL, 0, "$");
               agrega(con, jbuf, niv[i]);
               cambio = 1;
            }
         }
         i = i + 1;
      }
   }
}

/* elimina dobles negaciones que esten en tabla.
   hay que iterar porque puede haber ~~~~p y conviene ir de a poco */
void extrae_neg(void) {
   char interno[FMAX], sub[FMAX], jbuf[FMAX];
   int i, cambio, lim;
   cambio = 1;
   while (cambio == 1) {
      cambio = 0;
      lim = ntab;
      i = 0;
      while (i < lim) {
         if (tab[i][0] == CNEG) {
            get_sub(interno, tab[i], 0);
            if (interno[0] == CNEG) {
               get_sub(sub, interno, 0);
               if (busca(sub, ntab) < 0) {
                  build_jus(jbuf, "${\\neg \\neg}_e ~~ ", i + 1, NULL, 0, "$");
                  agrega(sub, jbuf, niv[i]);
                  cambio = 1;
               }
            }
         }
         i = i + 1;
      }
   }
}

/* modus ponens hacia adelante: para cada A->B en tabla, si A esta, agrega B.
   solo construye lo que todavia no esta para evitar bucles */
void adelante_imp(int nivel) {
   char ant[FMAX], con[FMAX], jbuf[FMAX];
   int i, cambio, lim, ra, ri;
   cambio = 1;
   while (cambio == 1) {
      cambio = 0;
      lim = ntab;
      i = 0;
      while (i < lim) {
         if (tab[i][0] == CIMP) {
            get_sub(ant, tab[i], 0);
            get_sub(con, tab[i], 1);
            ra = busca(ant, ntab);
            if (ra > 0 && busca(con, ntab) < 0) {
               ri = i + 1;
               build_jus(jbuf, "$\\rightarrow_e ~~ ", ri, ", ", ra, "$");
               agrega(con, jbuf, nivel);
               cambio = 1;
            }
         }
         i = i + 1;
      }
   }
}

/* modus tollens hacia adelante: A->B con ~B en tabla implica agregar ~A.
   esto fue necesario para cadenas tipo ~s->~r->~q->~p que el
   encadenamiento hacia atras solo no resolvia bien */
void adelante_mt(int nivel) {
   char ant[FMAX], con[FMAX], negcon[FMAX], negant[FMAX], jbuf[FMAX];
   int i, cambio, lim, rc, ri;
   cambio = 1;
   while (cambio == 1) {
      cambio = 0;
      lim = ntab;
      i = 0;
      while (i < lim) {
         if (tab[i][0] == CIMP) {
            get_sub(ant, tab[i], 0);
            get_sub(con, tab[i], 1);
            make_neg(negcon, con);
            make_neg(negant, ant);
            rc = busca(negcon, ntab);
            if (rc > 0 && busca(negant, ntab) < 0) {
               ri = i + 1;
               build_jus(jbuf, "MT ", ri, ", ", rc, NULL);
               agrega(negant, jbuf, nivel);
               cambio = 1;
            }
         }
         i = i + 1;
      }
   }
}

/* construye A^B cuando ambos estan en tabla Y A^B es antecedente
   de alguna implicacion. evita construir todas las combinaciones
   posibles (podria explotar con muchas variables) */
void adelante_and(int nivel) {
   char ant[FMAX], la[FMAX], lb[FMAX], jbuf[FMAX];
   int i, cambio, lim, ra, rb;
   cambio = 1;
   while (cambio == 1) {
      cambio = 0;
      lim = ntab;
      i = 0;
      while (i < lim) {
         if (tab[i][0] == CIMP) {
            get_sub(ant, tab[i], 0);
            if (ant[0] == CAND) {
               get_sub(la, ant, 0);
               get_sub(lb, ant, 1);
               ra = busca(la, ntab);
               rb = busca(lb, ntab);
               if (ra > 0 && rb > 0 && busca(ant, ntab) < 0) {
                  build_jus(jbuf, "$\\wedge_i ~~ ", ra, ", ", rb, "$");
                  agrega(ant, jbuf, nivel);
                  cambio = 1;
               }
            }
         }
         i = i + 1;
      }
   }
}

/* expande ~(A->B) usando la equivalencia ~(A->B) <=> A ^ ~B */
void expande_neg_imp(int nivel) {
   char interno[FMAX], ant[FMAX], con[FMAX], negcon[FMAX], jbuf[FMAX];
   int i, lim;
   lim = ntab;
   i = 0;
   while (i < lim) {
      if (tab[i][0] == CNEG) {
         get_sub(interno, tab[i], 0);
         if (interno[0] == CIMP) {
            get_sub(ant, interno, 0);
            get_sub(con, interno, 1);
            make_neg(negcon, con);
            if (busca(ant, ntab) < 0) {
               build_jus(jbuf, "$\\neg\\rightarrow_{e1} ~~ ", i + 1, NULL, 0, "$");
               agrega(ant, jbuf, niv[i]);
            }
            if (busca(negcon, ntab) < 0) {
               build_jus(jbuf, "$\\neg\\rightarrow_{e2} ~~ ", i + 1, NULL, 0, "$");
               agrega(negcon, jbuf, niv[i]);
            }
         }
      }
      i = i + 1;
   }
}

/* busca si hay algun par A / ~A en las primeras lim lineas de tabla */
int hay_contradiccion(int lim) {
   char neg[FMAX];
   int i;
   i = 0;
   while (i < lim) {
      make_neg(neg, tab[i]);
      if (busca(neg, lim) > 0) return 1;
      i = i + 1;
   }
   return 0;
}

/* satura la tabla aplicando todas las eliminaciones hacia adelante hasta punto fijo */
void satura(int nivel) {
   int ntab_antes, ntab_nuevo;
   ntab_antes = -1;
   ntab_nuevo = ntab;
   while (ntab_antes != ntab_nuevo) {
      ntab_antes = ntab_nuevo;
      extrae_and();
      extrae_neg();
      expande_neg_imp(nivel);
      adelante_and(nivel);
      adelante_imp(nivel);
      adelante_mt(nivel);
      ntab_nuevo = ntab;
   }
}

int demuestra(char *m, int nivel, int prof);

/* intenta derivar m usando lo que ya hay en tabla (eliminaciones) */
int elimina(char *m, int nivel, int prof) {
   char neg[FMAX], nn[FMAX];
   char ant[FMAX], con[FMAX];
   char ny[FMAX], nm[FMAX], nnm[FMAX];
   char jbuf[FMAX];
   int i, lim, r, ri, rd, sv;

   if (prof > 20) return -1;

   r = busca(m, ntab);
   if (r > 0) return r;

   satura(nivel);

   r = busca(m, ntab);
   if (r > 0) return r;

   lim = ntab;

   /* ex falso quodlibet: si hay contradiccion, todo es derivable */
   if (hay_contradiccion(lim) > 0) {
      build_jus(jbuf, "$\\bot_e$", 0, NULL, 0, NULL);
      return agrega(m, jbuf, nivel);
   }

   /* eliminacion directa de doble negacion: ~~m esta en tabla */
   make_neg(neg, m);
   make_neg(nn, neg);
   r = busca(nn, lim);
   if (r > 0) {
      build_jus(jbuf, "${\\neg \\neg}_e ~~ ", r, NULL, 0, "$");
      return agrega(m, jbuf, nivel);
   }

   /* modus ponens al reves: buscar A->m en tabla y tratar de demostrar A */
   i = 0;
   while (i < lim) {
      if (tab[i][0] == CIMP) {
         get_sub(con, tab[i], 1);
         if (sequ(con, m) == 1) {
            get_sub(ant, tab[i], 0);
            r = busca(ant, ntab);
            if (r < 0) r = elimina(ant, nivel, prof + 1);
            if (r > 0) {
               build_jus(jbuf, "$\\rightarrow_e ~~ ", i + 1, ", ", r, "$");
               return agrega(m, jbuf, nivel);
            }
         }
      }
      i = i + 1;
   }

   /* si m = ~~X y X esta en tabla, construir ~~X directamente
      (necesario para que MT pueda usarlo como premisa negada) */
   if (m[0] == CNEG) {
      get_sub(ant, m, 0);
      if (ant[0] == CNEG) {
         get_sub(con, ant, 0);
         r = busca(con, ntab);
         if (r > 0) {
            build_jus(jbuf, "${\\neg \\neg}_i ~~ ", r, NULL, 0, "$");
            return agrega(m, jbuf, nivel);
         }
      }
   }

   /* modus tollens hacia atras: m=~X, buscar X->Y y demostrar ~Y */
   if (m[0] == CNEG) {
      get_sub(ant, m, 0);
      i = 0;
      while (i < lim) {
         if (tab[i][0] == CIMP) {
            get_sub(con, tab[i], 0);
            if (sequ(con, ant) == 1) {
               get_sub(con, tab[i], 1);
               make_neg(ny, con);
               r = busca(ny, ntab);
               if (r < 0) r = elimina(ny, nivel, prof + 1);
               if (r > 0) {
                  build_jus(jbuf, "MT ", i + 1, ", ", r, NULL);
                  return agrega(m, jbuf, nivel);
               }
            }
         }
         i = i + 1;
      }
   }

   /* neg-neg-e indirecta: si m no es negacion, intentar derivar ~~m */
   if (m[0] != CNEG) {
      make_neg(nm, m);
      make_neg(nnm, nm);
      r = busca(nnm, ntab);
      if (r < 0) r = elimina(nnm, nivel, prof + 1);
      if (r > 0) {
         build_jus(jbuf, "${\\neg \\neg}_e ~~ ", r, NULL, 0, "$");
         return agrega(m, jbuf, nivel);
      }
   }

   /* introduccion de conjuncion: si m = A^B intentar demostrar A y B */
   if (m[0] == CAND) {
      sv = ntab;
      get_sub(ant, m, 0);
      get_sub(con, m, 1);
      ri = busca(ant, ntab);
      if (ri < 0) ri = demuestra(ant, nivel, prof + 1);
      rd = busca(con, ntab);
      if (rd < 0) rd = demuestra(con, nivel, prof + 1);
      if (ri > 0 && rd > 0) {
         build_jus(jbuf, "$\\wedge_i ~~ ", ri, ", ", rd, "$");
         return agrega(m, jbuf, nivel);
      }
      ntab = sv;
   }

   return -1;
}

/* punto de entrada del motor de deduccion */
int demuestra(char *m, int nivel, int prof) {
   char ant[FMAX], con[FMAX];
   char interno[FMAX], negk[FMAX];
   char jbuf[FMAX];
   char ant2[FMAX], con2[FMAX], jbuf2[FMAX];
   int r, ra, ls, lb, sv, ls2, k, r2, sv2, ra2, rb2;

   if (prof > 20) return -1;

   ra = busca(m, ntab);
   if (ra > 0) return ra;

   /* primero intentar por eliminacion */
   if (elimina(m, nivel, prof + 1) > 0) return ntab;

   /* ->_i: suponer antecedente, demostrar consecuente */
   if (m[0] == CIMP) {
      sv = ntab;
      get_sub(ant, m, 0);
      get_sub(con, m, 1);
      ls = agrega(ant, "Supuesto", nivel + 1);
      lb = demuestra(con, nivel + 1, prof + 1);
      if (lb < 0) {
         ntab = sv;
         return -1;
      }
      build_jus(jbuf, "$\\rightarrow_i ~~ ", ls, "-", lb, "$");
      return agrega(m, jbuf, nivel);
   }

   /* ~~_i: si m = ~~A, intentar demostrar A */
   if (m[0] == CNEG) {
      get_sub(interno, m, 0);
      if (interno[0] == CNEG) {
         get_sub(ant, interno, 0);
         ra = busca(ant, ntab);
         if (ra < 0) ra = demuestra(ant, nivel, prof + 1);
         if (ra > 0) {
            build_jus(jbuf, "${\\neg \\neg}_i ~~ ", ra, NULL, 0, "$");
            return agrega(m, jbuf, nivel);
         }
      }
   }

   /* ~_i: suponer ant(m), saturar, buscar contradiccion B y ~B.
      hay que saturar antes de buscar la contradiccion porque si no
      algunos casos con conjunciones en antecedentes no cerraban */
   if (m[0] == CNEG) {
      sv = ntab;
      get_sub(ant, m, 0);
      ls2 = agrega(ant, "Supuesto", nivel + 1);
      satura(nivel + 1);
      k = 0;
      r2 = -1;
      while (k < ls2 && r2 < 0) {
         make_neg(negk, tab[k]);
         sv2 = ntab;
         r2 = elimina(negk, nivel + 1, prof + 1);
         if (r2 < 0) {
            ntab = sv2;
            k = k + 1;
         }
      }
      if (r2 > 0) {
         build_jus(jbuf, "$\\neg_i ~~ ", ls2, "-", r2, "$");
         return agrega(m, jbuf, nivel);
      }
      ntab = sv;
   }

   return -1;
}

/* lee los simbolos acumulados, analiza premisas y conclusion,
   y llama al motor de deduccion */
void procesa(void) {
   char prem[MAX][FMAX];
   char conc[FMAX];
   int nprem, vdash, i, r;

   vdash = -1;
   i = 0;
   while (i < ntokens) {
      if (tokens[i] == TOK_VDASH) vdash = i;
      i = i + 1;
   }

   nprem = 0;
   pos = 0;

   if (vdash > 0) {
      while (pos < vdash) {
         parse_formula(prem[nprem]);
         if (prem[nprem][0]) nprem = nprem + 1;
         if (pos < vdash && tokens[pos] == TOK_COMMA) pos = pos + 1;
      }
   }

   if (vdash > -1) pos = vdash + 1;
   else            pos = 0;

   parse_formula(conc);

   ntab = 0;
   i = 0;
   while (i < nprem) {
      agrega(prem[i], "Premisa", 0);
      i = i + 1;
   }

   r = demuestra(conc, 0, 0);
   if (r < 0) printf("%% No se pudo demostrar.\n");
   else        imprime();
}

%}

letra    [a-zA-Z]
variable {letra}+
esp      [ \t\n\r]+
neg      \\neg
conj     \\wedge
impl     \\rightarrow
vdash    \\vdash
mbox     \\mbox\{\\bf[ \t]*{variable}[ \t]*\}
delim    \$\$

%%

{delim} {
   if (dentro == 0) {
      dentro  = 1;
      ntokens = 0;
   } else {
      dentro = 0;
      procesa();
   }
}

{mbox} {
   int ii, jj;
   if (dentro == 1) {
      /* saltar hasta la 'f' de \bf y luego extraer el nombre */
      ii = 0;
      while (yytext[ii] && yytext[ii] != 'f') ii = ii + 1;
      ii = ii + 1;
      while (yytext[ii] == ' ' || yytext[ii] == '\t') ii = ii + 1;
      jj = 0;
      while (yytext[ii] && yytext[ii] != '}' && jj < NMAX - 1) {
         tokvar[ntokens][jj] = yytext[ii];
         ii = ii + 1;
         jj = jj + 1;
      }
      /* recortar espacios al final del nombre */
      while (jj > 0 && tokvar[ntokens][jj - 1] == ' ') jj = jj - 1;
      tokvar[ntokens][jj] = '\0';
      tokens[ntokens] = TOK_VAR;
      ntokens = ntokens + 1;
   }
}

{neg}   { if (dentro == 1) { tokens[ntokens] = TOK_NEG;    ntokens = ntokens + 1; } }
{conj}  { if (dentro == 1) { tokens[ntokens] = TOK_AND;    ntokens = ntokens + 1; } }
{impl}  { if (dentro == 1) { tokens[ntokens] = TOK_IMP;    ntokens = ntokens + 1; } }
{vdash} { if (dentro == 1) { tokens[ntokens] = TOK_VDASH;  ntokens = ntokens + 1; } }
"("     { if (dentro == 1) { tokens[ntokens] = TOK_LPAREN; ntokens = ntokens + 1; } }
")"     { if (dentro == 1) { tokens[ntokens] = TOK_RPAREN; ntokens = ntokens + 1; } }
","     { if (dentro == 1) { tokens[ntokens] = TOK_COMMA;  ntokens = ntokens + 1; } }

{esp} { }
.     { }

%%

int main(void) {
   dentro  = 0;
   ntokens = 0;
   ntab    = 0;
   yylex();
   return 0;
}
