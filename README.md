# sshare & moransub

Two Stata commands for spatial regional analysis. Pure Stata + Mata,
no dependencies. Requires Stata 17 or newer.

- **`sshare`** — traditional (Dunn) and spatial (Nazara–Hewings)
  shift-share decomposition. Decomposes the growth of every unit-area
  pair against the full economy (`CN = EE + ED`) and, with the
  `spatial` option, against the neighborhood defined by a contiguity
  matrix (`CNL = EEL + EDL`). Results go to `r()` by default
  (including the `r(units)` and `r(effects)` matrices); the
  `generate` option adds the effects as dataset variables.
- **`moransub`** — Moran's I computed unit by unit, restricted to the
  subgraph of areas holding data for that unit, with a two-tailed
  permutation p-value.

Both commands read the spatial weight matrix either from an edge list
embedded in the dataset characteristics (`_dta[W_n]`, `_dta[W_links]`,
`_dta[W_idvar]`) or from an external `.mmat` file via `wfile()`.

## Installation

From Stata:

```stata
net install sshare, from(https://raw.githubusercontent.com/joseamaltesup/sshare-package/main/)
```

or copy the `.ado` and `.sthlp` files to your personal ado
directory (`sysdir` shows it).

## Documentation

```stata
help sshare
help moransub
```

A step-by-step guide in Spanish for non-programmers is in
[GUIA.md](GUIA.md).

## License

MIT — see [LICENSE](LICENSE).

## Origin

These commands were written for the chapter "La Resiliencia Economica
Regional y por Clusteres Industriales: Analisis Logistico de Cambio y
Participacion Espacial en Mexico" of *Econometria Aplicada con Stata*
(Stata Press).
