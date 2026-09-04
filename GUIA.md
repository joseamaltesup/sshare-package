# Guía de uso de `sshare` y `moransub`

Esta guía explica, paso a paso y sin suponer experiencia en
programación, cómo usar los dos comandos con sus propios datos.
Basta con saber abrir Stata y escribir órdenes en la ventana de
comandos. La referencia técnica completa está en la ayuda instalada
(`help sshare` y `help moransub`).

---

## 1. Qué hacen, en términos económicos

**`sshare`** responde: *¿el crecimiento de esta actividad en esta
región se debe al empuje nacional, a la estructura del sector, o a
la competitividad propia de la región?* Es la descomposición
shift-share clásica (Dunn) y, si usted aporta un mapa de vecindades,
también la versión espacial de Ramajo y Márquez (2008): la misma
pregunta, pero comparando contra los vecinos en lugar de contra el
país. Ambas se reportan en la misma corrida, que es justamente lo que
esos autores proponen: un solo modelo con los efectos globales y los
locales.

**`moransub`** responde: *¿el crecimiento de esta actividad está
geográficamente agrupado?* — es decir, ¿las regiones donde crece son
vecinas entre sí? Calcula la I de Moran actividad por actividad,
usando en cada caso solo las regiones que tienen dato, y entrega un
p-value que le dice si el agrupamiento es estadísticamente
significativo. Sirve como filtro: la versión espacial del
shift-share solo aporta información donde la I de Moran es
significativa.

---

## 2. Instalación (una sola vez)

Abra Stata y escriba en la ventana de comandos:

```stata
net install sshare, from(https://raw.githubusercontent.com/joseamaltesup/sshare-package/main/)
```

Para comprobar que quedó instalado:

```stata
help sshare
```

Si se abre la ayuda, está listo. Requiere Stata 17 o más reciente.

---

## 3. Cómo deben verse sus datos

Los comandos trabajan con una base donde **cada fila es una
combinación actividad × región**. Por ejemplo, con 10 actividades y
32 estados, la base tiene 320 filas. Se necesitan estas columnas:

| Columna | Qué es | Ejemplo |
|---|---|---|
| identificador de la actividad | numérico o texto | `actividad` |
| identificador de la región | la clave oficial | `estado` (1–32) |
| la variable en el año inicial | una columna por año | `empleo2018` |
| la variable en el año final | | `empleo2023` |

Dos advertencias importantes:

- **No rellene datos faltantes con ceros.** En las fuentes oficiales
  un dato faltante suele ser reserva por confidencialidad, no
  ausencia de actividad. Los comandos saben tratar los faltantes;
  un cero inventado produce tasas de crecimiento falsas.
- **Si su identificador de actividad se repite entre grupos** (por
  ejemplo, el subsector 1 existe dentro de varios sectores), cree
  una clave única antes de empezar:
  `generate llave = sector * 1000 + subsector`.

---

## 4. El mapa de vecindades (matriz W)

Para la parte espacial, los comandos necesitan saber qué regiones
son vecinas. Eso es la "matriz W". Hay dos situaciones:

**a) Le compartieron una base que ya la trae.** No tiene que hacer
nada: los comandos la encuentran solos. Puede verla con
`char list _dta[]`.

**b) Tiene que construirla usted, desde un shapefile oficial** (el
archivo de mapa `.shp` de su país). Se hace una sola vez, con
comandos que ya vienen en Stata:

```stata
spshape2dta "mi_mapa", saving(mi_mapa_stata) replace
use mi_mapa_stata.dta, clear
spmatrix create contiguity W, rook normalize(none) replace
spmatrix matafromsp Wbin idb = W
mata: mata matsave "mi_matriz" Wbin idb, replace
```

Con eso queda el archivo `mi_matriz.mmat`. Dos detalles que importan:
use siempre la opción `rook` (sin ella, fronteras reales pueden
perderse por imprecisiones del mapa) y `normalize(none)` (los
comandos hacen su propia estandarización). Necesitará también una
columna en su base con la **posición de cada región en la matriz**
(el orden de filas del shapefile); llámela por ejemplo `pos_w`.

---

## 5. Primer paso: ¿hay estructura espacial? (`moransub`)

Se corre sobre la tasa de crecimiento. Si no la tiene, créela:

```stata
generate g = (empleo2023 - empleo2018) / empleo2018 ///
    if !missing(empleo2018, empleo2023) & empleo2018 > 0
```

Y entonces:

```stata
moransub g, by(actividad) wfile(mi_matriz) wid(pos_w)
```

(si la base ya trae la matriz incorporada, omita `wfile()` y
`wid()`). El comando imprime una tabla con una fila por actividad:

- **I** — la I de Moran: positiva = las regiones que crecen tienden
  a ser vecinas; cercana a E(I) = sin patrón espacial.
- **p-value** — la significancia, calculada por permutación (9,999
  barajadas por defecto). Las estrellas marcan el 10%, 5% y 1%.
- **(n<20)** — la actividad tiene pocas regiones con dato; el
  resultado se reporta pero no se considera confiable.

El comando también deja en la base una variable `moran_sig` que vale
1 para las actividades con agrupamiento significativo y confiable:
esas son las candidatas al análisis espacial.

---

## 6. Segundo paso: la descomposición (`sshare`)

```stata
sshare empleo, by(actividad) t0(2018) t1(2023) spatial ///
    wfile(mi_matriz) wid(pos_w)
```

(de nuevo: sin `wfile()`/`wid()` si la matriz viaja en la base; sin
`spatial` si solo quiere la versión tradicional). La lectura de los
efectos, en palabras:

- **CN = EE + ED** (versión tradicional). `CN` es cuánto le fue a la
  región mejor o peor que al país. `EE` es la parte que explica el
  sector (¿el sector nacional empuja o frena?). `ED` es la parte
  propia de la región (¿supera a su propio sector?).
- **CNL = EEL + EDL** (versión espacial). Lo mismo, pero el punto de
  comparación son los estados vecinos en lugar del país.

**Importante**: corra `sshare` sobre la base completa. Si quiere ver
solo un sector, no borre filas (`keep`): eso contaminaría el punto de
comparación nacional. Use la opción de vista:

```stata
sshare, show(traditional) showif(actividad == 5)
```

Note que la segunda llamada no repite nada: escribir `sshare` a
secas vuelve a mostrar resultados de la corrida anterior, y `show()`
elige la tabla (`growth`, `regional`, `traditional`, `spatial`,
`both`, `areas`). Otras opciones útiles: `percent` (cifras en
porcentaje), `label(nombre_actividad)` y `arealabel(nombre_region)`
para tablas legibles.

Si quiere los efectos como columnas de su base (por ejemplo, para
graficarlos o exportarlos), añada la opción `generate`:

```stata
sshare empleo, by(actividad) t0(2018) t1(2023) spatial generate
```

---

## 7. Problemas frecuentes

| Stata dice | Qué significa y qué hacer |
|---|---|
| Mensajes de error en español, o un comportamiento que no coincide con esta guía | Está corriendo una copia VIEJA del comando que quedó en su máquina. Ejecute `which sshare`: si la ruta no es la carpeta `plus` de Stata, borre ese archivo viejo. Luego reinstale con la línea de la sección 2 añadiendo `replace` al final, y ejecute `discard`. `which sshare` debe mostrar la versión nueva. |
| `variable CN already exists and was not created by sshare` | Ya existe una columna suya con ese nombre. Renómbrela, o use `prefix(mi_)` para que los efectos se llamen `mi_CN`, `mi_EE`, ... |
| `spatial requires a weight matrix` | Ni la base trae matriz ni indicó `wfile()`. Vea la sección 4. |
| `wid() has # values outside 1..32` | La columna de posición no corresponde a la matriz: cada región debe tener el número de fila que ocupa en W. |
| `no rows with year == 2018 hold data` | Los años de `t0()`/`t1()` no coinciden con los de sus datos. |
| El benchmark G sale raro | Probablemente corrió `sshare` después de borrar filas con `keep`. Vuelva a cargar la base completa. |

---

## 8. Reproducibilidad

`moransub` usa una semilla fija (12345 por defecto), así que dos
corridas con los mismos datos dan exactamente los mismos p-values, en
su computadora y en la de sus coautores. Puede cambiarla con
`seed()`, y el comando nunca altera el generador de números
aleatorios del resto de su sesión.
