![nasus](https://github.com/archkr0w/archlxgger/assets/126942746/bbe2d901-2b2f-4dd2-a739-7c935d30b8ee)

## Compilar y ejecutar

```bash
flex tarea1.lex && gcc -o tarea1.exe lex.yy.c -ll
./tarea1.exe < expresion.txt
```

---

## Guía rápida de Git (para los que nunca lo han usado)

### 1. Clonar el repositorio

Esto descarga el proyecto a tu computador. Solo se hace **una vez**.

```bash
git clone git@github.com:archkr0w/lab1logicc.git
cd lab1logicc
```

---

### 2. Antes de ponerte a editar — actualiza tu copia local

Siempre haz esto antes de tocar cualquier archivo, para traer los cambios que otros hayan subido:

```bash
git pull
```

---

### 3. Edita los archivos que necesites

Abre `tarea1.lex` (o lo que sea) y haz tus cambios normalmente.

---

### 4. Ver qué archivos cambiaste

```bash
git status
```

Te muestra en rojo los archivos que modificaste y aún no has preparado para subir.

---

### 5. Preparar los cambios para el commit

```bash
git add tarea1.lex
```

O si quieres agregar todos los archivos modificados de una:

```bash
git add .
```

---

### 6. Hacer el commit — guardar los cambios con un mensaje

El mensaje debe describir **qué cambiaste y por qué**, no solo "cambios" o "arreglé cosas".

```bash
git commit -m "Agrega regla de eliminacion para conjuncion"
```

Ejemplos de buenos mensajes:
- `"Corrige bug en demuestra cuando la meta es negacion"`
- `"Agrega soporte para doble negacion en elimina"`
- `"Ajusta colores de salida LaTeX para nivel 2"`

---

### 7. Subir los cambios a GitHub

```bash
git push
```

---

### Flujo completo de ejemplo

```bash
git pull                          # traer cambios del repo
# ... editas tarea1.lex ...
git status                        # ver qué cambió
git add tarea1.lex                # preparar el archivo
git commit -m "Mensaje claro"     # guardar con descripción
git push                          # subir a GitHub
```

---

### Si hay conflicto (dos personas editaron lo mismo)

Git te avisa con un mensaje como `CONFLICT`. Abre el archivo, busca las líneas marcadas con `<<<<<<<` y `>>>>>>>`, elige qué versión dejar, guarda, y luego:

```bash
git add tarea1.lex
git commit -m "Resuelve conflicto en tarea1.lex"
git push
```
