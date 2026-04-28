%{
/* tarea1.lex - Deduccion Natural | Logica Computacional 22625 */
/* Compilar: flex tarea1.lex && gcc -o tarea1.exe lex.yy.c -ll  */
/* Ejecutar: ./tarea1.exe < expresion.txt                        */
#include <stdio.h>
#include <stdlib.h>
#define VAR 0
#define NEG 1
#define AND 2
#define IMP 3
#define MAX 64
struct F { int t; char n[32]; struct F *i, *d; };
struct L { int num; struct F *f; char j[MAX]; int niv; };
struct F *prem[MAX]; struct L tab[MAX];
int nprem, ntab, dentro, vtab;
struct F *pf[MAX]; int tf; int po[MAX]; int to;

/* Crear nodo de formula */
struct F *nf(int t) {
   struct F *f;
   f = calloc(1, sizeof(struct F));
   f->t = t;
   return f;
}

/* Comparar estructuralmente dos formulas */
int eq(struct F *a, struct F *b) {
   int i;
   if (!a || !b) return a == b;
   if (a->t != b->t) return 0;
   if (a->t == VAR) {
      i = 0;
      while (a->n[i] && b->n[i] && a->n[i] == b->n[i]) i = i + 1;
      return a->n[i] == b->n[i];
   }
   return eq(a->i, b->i) && eq(a->d, b->d);
}

/* Convertir entero a string (sin sprintf) */
int itos(char *buf, int n) {
   char tmp[16]; int i, k, len;
   i = 0;
   if (n == 0) { tmp[0] = '0'; i = 1; }
   while (n > 0) { tmp[i] = '0' + (n % 10); i = i + 1; n = n / 10; }
   len = i; k = 0;
   while (k < len) { buf[k] = tmp[len - 1 - k]; k = k + 1; }
   buf[len] = '\0';
   return len;
}

/* Agregar linea a la tabla */
int agrega(struct F *f, char *j, int niv) {
   int i;
   tab[ntab].num = ntab + 1;
   tab[ntab].f   = f;
   tab[ntab].niv = niv;
   i = 0;
   while (j[i] && i < MAX - 1) { tab[ntab].j[i] = j[i]; i = i + 1; }
   tab[ntab].j[i] = '\0';
   ntab = ntab + 1;
   return ntab;
}

/* Agregar linea con justificacion pre+a+sep+b+suf construida internamente */
int agrj(struct F *f, char *pre, int a, char *sep, int b, char *suf, int niv) {
   char j[MAX]; int k, p; char na[8], nb[8];
   k = 0; p = 0;
   while (pre[p] && k < MAX - 1) { j[k] = pre[p]; k = k + 1; p = p + 1; }
   if (a > 0) {
      itos(na, a); p = 0;
      while (na[p] && k < MAX - 1) { j[k] = na[p]; k = k + 1; p = p + 1; }
   }
   if (sep) {
      p = 0;
      while (sep[p] && k < MAX - 1) { j[k] = sep[p]; k = k + 1; p = p + 1; }
   }
   if (b > 0) {
      itos(nb, b); p = 0;
      while (nb[p] && k < MAX - 1) { j[k] = nb[p]; k = k + 1; p = p + 1; }
   }
   if (suf) {
      p = 0;
      while (suf[p] && k < MAX - 1) { j[k] = suf[p]; k = k + 1; p = p + 1; }
   }
   j[k] = '\0';
   return agrega(f, j, niv);
}

/* Buscar formula en tabla (retorna nro de linea o -1) */
int busca(struct F *f, int lim) {
   int i;
   i = 0;
   while (i < lim && i < ntab) {
      if (eq(tab[i].f, f)) return i + 1;
      i = i + 1;
   }
   return -1;
}

/* Imprimir formula en LaTeX */
void pflat(struct F *f) {
   if (!f) return;
   if (f->t == VAR) { printf("\\mbox{\\bf %s}", f->n); return; }
   if (f->t == NEG) {
      printf("\\neg ");
      if (f->i && (f->i->t == IMP || f->i->t == AND)) {
         printf("("); pflat(f->i); printf(")");
      } else pflat(f->i);
      return;
   }
   if (f->i && f->i->t == IMP) { printf("("); pflat(f->i); printf(")"); }
   else pflat(f->i);
   if (f->t == AND) printf(" \\wedge "); else printf(" \\rightarrow ");
   if (f->d && f->d->t == IMP) { printf("("); pflat(f->d); printf(")"); }
   else pflat(f->d);
}

/* Aplicar operador del tope de pila sobre los dos operandos del tope */
void aplica(void) {
   struct F *f;
   f = nf(po[to - 1]); to = to - 1;
   f->d = pf[tf - 1]; tf = tf - 1;
   f->i = pf[tf - 1]; tf = tf - 1;
   pf[tf] = f; tf = tf + 1;
}

/* Aplicar negaciones pendientes sobre el tope de la pila de formulas */
void apnegs(void) {
   struct F *g;
   while (to > 0 && po[to - 1] == NEG) {
      to = to - 1;
      g = nf(NEG);
      g->i = pf[tf - 1];
      pf[tf - 1] = g;
   }
}

/* Empujar operador binario respetando precedencia (shunting-yard) */
void pushop(int op) {
   int ok, t;
   ok = 1;
   while (to > 0 && ok == 1) {
      t = po[to - 1];
      if (t < 0 || t == NEG)        ok = 0;
      else if (t > op)               aplica();
      else if (t == op && t != IMP)  aplica();
      else                           ok = 0;
   }
   po[to] = op; to = to + 1;
}

/* Cerrar parentesis: aplicar hasta centinela */
void cierra(void) {
   while (to > 0 && po[to - 1] >= 0) aplica();
   if (to > 0) to = to - 1;
   apnegs();
}

/* Finalizar formula: aplicar operadores restantes y retornar raiz */
struct F *fin(void) {
   while (to > 0 && po[to - 1] >= 0) aplica();
   if (tf > 0) { tf = tf - 1; return pf[tf]; }
   return NULL;
}

int demuestra(struct F *m, int niv);

/* Aplicar reglas de eliminacion para derivar meta */
int elimina(struct F *m, int niv) {
   int i, lim, r, ri, rd;
   struct F neg, nn;
   struct F *ny, *nm, *nnm;
   r = busca(m, ntab);
   if (r > 0) return r;
   lim = ntab;
   /* neg-neg-e directa: buscar ~~m en tabla */
   neg.t = NEG; neg.i = m;    neg.d = NULL;
   nn.t  = NEG; nn.i  = &neg; nn.d  = NULL;
   r = busca(&nn, lim);
   if (r > 0) return agrj(m, "${\\neg \\neg}_e ~~ ", r, NULL, 0, "$", niv);
   /* ->_e (modus ponens): buscar A->m y demostrar A */
   i = 0;
   while (i < lim) {
      if (tab[i].f->t == IMP && eq(tab[i].f->d, m)) {
         r = busca(tab[i].f->i, ntab);
         if (r < 0) r = demuestra(tab[i].f->i, niv);
         if (r > 0) return agrj(m, "$\\rightarrow_e ~~ ", i + 1, ", ", r, "$", niv);
      }
      i = i + 1;
   }
   /* MT: m=~X, buscar X->Y en tabla, demostrar ~Y */
   if (m->t == NEG) {
      i = 0;
      while (i < lim) {
         if (tab[i].f->t == IMP && eq(tab[i].f->i, m->i)) {
            ny = calloc(1, sizeof(struct F));
            ny->t = NEG; ny->i = tab[i].f->d; ny->d = NULL;
            r = busca(ny, ntab);
            if (r < 0) r = demuestra(ny, niv);
            if (r > 0) return agrj(m, "MT ", i + 1, ", ", r, NULL, niv);
         }
         i = i + 1;
      }
   }
   /* neg-neg-e indirecta: generar ~~m via MT y eliminar doble negacion */
   if (m->t != NEG) {
      nm  = calloc(1, sizeof(struct F));
      nm->t  = NEG; nm->i  = m;  nm->d  = NULL;
      nnm = calloc(1, sizeof(struct F));
      nnm->t = NEG; nnm->i = nm; nnm->d = NULL;
      r = busca(nnm, ntab);
      if (r < 0) r = elimina(nnm, niv);
      if (r > 0) return agrj(m, "${\\neg \\neg}_e ~~ ", r, NULL, 0, "$", niv);
   }
   /* ^_e1 y ^_e2 */
   i = 0;
   while (i < lim) {
      if (tab[i].f->t == AND && eq(tab[i].f->i, m))
         return agrj(m, "$\\wedge_{e1} ~~ ", i + 1, NULL, 0, "$", niv);
      if (tab[i].f->t == AND && eq(tab[i].f->d, m))
         return agrj(m, "$\\wedge_{e2} ~~ ", i + 1, NULL, 0, "$", niv);
      i = i + 1;
   }
   /* ^_i */
   if (m->t == AND) {
      ri = busca(m->i, ntab); if (ri < 0) ri = demuestra(m->i, niv);
      rd = busca(m->d, ntab); if (rd < 0) rd = demuestra(m->d, niv);
      if (ri > 0 && rd > 0) return agrj(m, "$\\wedge_i ~~ ", ri, ", ", rd, "$", niv);
   }
   return -1;
}

/* Demostrar formula usando backward chaining */
int demuestra(struct F *m, int niv) {
   int ls, lb, ra, sv, ls2, k, r2, sv2;
   struct F *negk;
   if (busca(m, ntab) > 0) return busca(m, ntab);
   if (elimina(m, niv) > 0) return ntab;
   /* ->_i: suponer antecedente y demostrar consecuente */
   if (m->t == IMP) {
      ls = agrega(m->i, "Supuesto", niv + 1);
      lb = demuestra(m->d, niv + 1);
      if (lb < 0) return -1;
      return agrj(m, "$\\rightarrow_i ~~ ", ls, "-", lb, "$", niv);
   }
   /* neg-neg-i */
   if (m->t == NEG && m->i && m->i->t == NEG) {
      ra = busca(m->i->i, ntab);
      if (ra < 0) ra = demuestra(m->i->i, niv);
      if (ra > 0) return agrj(m, "${\\neg \\neg}_i ~~ ", ra, NULL, 0, "$", niv);
   }
   /* neg-i: asumir m->i, buscar contradiccion B y ~B */
   if (m->t == NEG) {
      sv = ntab;
      ls2 = agrega(m->i, "Supuesto", niv + 1);
      k = 0; r2 = -1;
      while (k < ls2 && r2 < 0) {
         negk = calloc(1, sizeof(struct F));
         negk->t = NEG; negk->i = tab[k].f; negk->d = NULL;
         sv2 = ntab;
         r2 = elimina(negk, niv + 1);
         if (r2 < 0) { ntab = sv2; k = k + 1; }
      }
      if (r2 > 0) return agrj(m, "$\\neg_i ~~ ", ls2, "-", r2, "$", niv);
      ntab = sv;
   }
   return -1;
}

/* Imprimir demostracion completa en LaTeX */
void imprime(void) {
   int i; char *col;
   printf("{\\tiny\n\\begin{tabular}{r l l}\n");
   i = 0;
   while (i < ntab) {
      if (tab[i].niv == 1)      col = "green";
      else if (tab[i].niv == 2) col = "red";
      else                      col = "blue";
      if (tab[i].niv == 0 && tab[i].j[0] == 'P') {
         printf("%d & $", tab[i].num);
         pflat(tab[i].f);
         printf("$ & %s \\\\ \\\\\n", tab[i].j);
      } else {
         printf("{\\color{%s} %d} & {\\color{%s} $", col, tab[i].num, col);
         pflat(tab[i].f);
         printf("$} & {\\color{%s} %s} \\\\ \\\\\n", col, tab[i].j);
      }
      i = i + 1;
   }
   printf("\\end{tabular}\n}\n\n");
}

%}

letra      [a-zA-Z]
variable   {letra}+
esp        [ \t\n\r]+
neg        \\neg
conj       \\wedge
impl       \\rightarrow
vdash      \\vdash
mbox       \\mbox\{\\bf[ \t]*{variable}[ \t]*\}
delim      \$\$

%%

{delim} {
   if (dentro == 0) {
      dentro = 1; tf = 0; to = 0; ntab = 0; nprem = 0; vtab = 0;
   } else {
      int i, r; struct F *conc;
      dentro = 0;
      conc = fin();
      if (conc) {
         i = 0;
         while (i < nprem) { agrega(prem[i], "Premisa", 0); i = i + 1; }
         r = demuestra(conc, 0);
         if (r < 0) printf("%% No se pudo demostrar.\n");
         else imprime();
      }
   }
}

{mbox} {
   /* Extraer nombre de variable de \mbox{\bf nombre} */
   int ii, jj; char nm[32]; struct F *f;
   if (dentro == 1) {
      ii = 0;
      while (yytext[ii] && yytext[ii] != 'f') ii = ii + 1;
      ii = ii + 1;
      while (yytext[ii] == ' ' || yytext[ii] == '\t') ii = ii + 1;
      jj = 0;
      while (yytext[ii] && yytext[ii] != '}' && jj < 31) {
         nm[jj] = yytext[ii]; ii = ii + 1; jj = jj + 1;
      }
      while (jj > 0 && nm[jj - 1] == ' ') jj = jj - 1;
      nm[jj] = '\0';
      f = nf(VAR);
      ii = 0;
      while (nm[ii] && ii < 31) { f->n[ii] = nm[ii]; ii = ii + 1; }
      f->n[ii] = '\0';
      pf[tf] = f; tf = tf + 1;
      apnegs();
   }
}

{neg}   { if (dentro == 1) { po[to] = NEG; to = to + 1; } }
{conj}  { if (dentro == 1) pushop(AND); }
{impl}  { if (dentro == 1) pushop(IMP); }

{vdash} {
   /* Guardar premisa anterior y resetear pilas para la conclusion */
   struct F *f;
   if (dentro == 1) {
      f = fin();
      if (f && nprem < MAX) { prem[nprem] = f; nprem = nprem + 1; }
      tf = 0; to = 0; vtab = 1;
   }
}

"(" { if (dentro == 1) { po[to] = -1; to = to + 1; } }
")" { if (dentro == 1) cierra(); }

"," {
   /* Separador de premisas (solo antes del vdash) */
   struct F *f;
   if (dentro == 1 && vtab == 0) {
      f = fin();
      if (f && nprem < MAX) { prem[nprem] = f; nprem = nprem + 1; }
      tf = 0; to = 0;
   }
}

{esp} { }
.     { }

%%

int main(void) {
   dentro = 0;
   yylex();
   return 0;
}
