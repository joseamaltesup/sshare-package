{smcl}
{* *! version 3.2.3  04sep2026}{...}
{viewerjumpto "Syntax" "sshare##syntax"}{...}
{viewerjumpto "Description" "sshare##description"}{...}
{viewerjumpto "Data formats" "sshare##formats"}{...}
{viewerjumpto "Options" "sshare##options"}{...}
{viewerjumpto "Display options" "sshare##display"}{...}
{viewerjumpto "The spatial option" "sshare##spatial"}{...}
{viewerjumpto "Stored results" "sshare##results"}{...}
{viewerjumpto "Examples" "sshare##examples"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col :{cmd:sshare} {hline 2}}Traditional (Dunn) and spatial
(Ramajo-Marquez) shift-share decomposition{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}Wide format (one column per year):

{p 8 16 2}
{cmd:sshare} {it:ystub} {ifin}{cmd:,}
{opt by(varname)} {opt t0(#)} {opt t1(#)}
[{it:options}]

{pstd}Long format (one row per year):

{p 8 16 2}
{cmd:sshare} {varname} {ifin}{cmd:,}
{opt by(varname)} {opt t0(#)} {opt t1(#)}
{opt year(varname)} [{opt id(varlist)}] [{it:options}]

{pstd}Replay (silently recompute from the stored run record and
redisplay):

{p 8 16 2}
{cmd:sshare} [{cmd:,} {opt show(list)} {opt showif(exp)}
{opt perc:ent} {opt notab:le} {opt lab:el(varname)}
{opt area:label(varname)}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt by(varname)}}unit identifier (numeric or string){p_end}
{synopt:{opt t0(#)}}base year{p_end}
{synopt:{opt t1(#)}}final year{p_end}

{syntab:Long format}
{synopt:{opt year(varname)}}year variable; switches to long format{p_end}
{synopt:{opt id(varlist)}}area identifier within {opt by()}; default
{opt wid()} or {cmd:char _dta[W_idvar]}{p_end}

{syntab:Spatial}
{synopt:{opt spatial}}compute the Ramajo-Marquez local effects{p_end}
{synopt:{opt wid(varname)}}row position in W; default
{cmd:char _dta[W_idvar]}{p_end}
{synopt:{opt wfile(filename)}}read W from a {cmd:.mmat} file instead of
the embedded edge list{p_end}
{synopt:{opt wobj(name)}}Mata object name inside {opt wfile()};
default {cmd:Wbin}{p_end}

{syntab:Benchmark and output}
{synopt:{opt gbench(#)}}use {it:#} as the national benchmark G instead
of computing it{p_end}
{synopt:{opt gen:erate}}add the effects to the dataset as variables;
without it the dataset is left untouched and results live in
{cmd:r()}{p_end}
{synopt:{opt pre:fix(name)}}prefix for the generated variables
(requires {opt generate}){p_end}
{synopt:{opt replace}}overwrite existing variables NOT created by
{cmd:sshare} (requires {opt generate}){p_end}

{syntab:Display}
{synopt:{opt show(list)}}any of {cmd:growth} (default), {cmd:regional},
{cmd:traditional}, {cmd:spatial}, {cmd:both}, {cmd:areas}{p_end}
{synopt:{opt showif(exp)}}restrict which units are displayed (not
computed){p_end}
{synopt:{opt perc:ent}}display effects in percent{p_end}
{synopt:{opt notab:le}}suppress all tables{p_end}
{synopt:{opt lab:el(varname)}}readable unit name{p_end}
{synopt:{opt area:label(varname)}}readable area name{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sshare} decomposes the growth of {it:ystub} between {opt t0()} and
{opt t1()} for every unit-area pair. The traditional decomposition
(Dunn) computes, per pair, the growth rate {cmd:g}, the unit's national
rate {cmd:G_i}, and the effects {cmd:CN} = g - G, {cmd:EE} = G_i - G and
{cmd:ED} = g - G_i, so that {cmd:CN = EE + ED} and
{cmd:g = G + EE + ED}.

{pstd}
By default the results are returned in {cmd:r()} -- the scalars, plus
the matrices {cmd:r(units)} and {cmd:r(effects)} -- and the dataset is
left untouched. The {opt generate} option additionally writes the
effects as dataset variables.

{pstd}
With {opt spatial}, the spatial extension of Ramajo and Marquez (2008)
replaces the national benchmark with the neighborhood: {cmd:Wg} is the aggregate
growth of the area's neighbors, {cmd:Wg_i} the unit's growth in those
neighbors, and the local effects are {cmd:CNL} = g - Wg,
{cmd:EEL} = Wg_i - Wg and {cmd:EDL} = g - Wg_i, with
{cmd:CNL = EEL + EDL}. The spatial lag averages ONLY over neighbors
with data, rescaling the weights; a missing neighbor never enters as a
zero. {cmd:n_nbrs} records how many neighbors carried data.

{pstd}
A growth rate exists only when both years hold valid data and the base
is positive (complete-pair rule): in many official sources a missing
value is a confidentiality suppression, not absence of activity.

{pstd}
Benchmarks (G, {cmd:g_reg}, {cmd:Wg}, {cmd:Wg_i}) are computed over the
FULL dataset; {it:if/in} restricts which rows receive a decomposition,
never what they are compared against.

{pstd}
Under {opt generate}, variables created by {cmd:sshare} carry the
variable characteristic {cmd:varname[sshare]} and are regenerated
silently on the next run; {opt replace} is needed only to overwrite a
variable the user created.


{marker formats}{...}
{title:Data formats}

{pstd}
{ul:Wide} (default): {it:ystub} is a stub; with {cmd:t0(2018)} and
{cmd:t1(2023)} the command reads {it:ystub}{cmd:2018} and
{it:ystub}{cmd:2023}. One row per unit-area pair.

{pstd}
{ul:Long}: with {opt year(varname)}, {it:ystub} is an existing numeric
variable and each unit-area series has one row per year. {opt id()}
names the variable(s) identifying the area within {opt by()}
(typically the area key, which is often also {opt wid()}). The command
requires a unique row per {opt by()} x {opt id()} x year at t0 and t1,
takes the pair values from those rows, and writes every result on ALL
rows of the pair (so a later {cmd:keep if year == 2023} keeps them).
Sums and counts use each pair exactly once.


{marker options}{...}
{title:Options}

{phang}{opt by(varname)} identifies the unit (cluster, subcluster).
String variables are accepted; a numeric key is built internally and
the string is used as the display label and as the row name in the
result matrices.

{phang}{opt gbench(#)} fixes the national benchmark externally. Use it
when the dataset was trimmed with {cmd:keep}/{cmd:drop} before calling
{cmd:sshare}, so that G still refers to the full economy.

{phang}{opt generate} writes the effects to the dataset:
{cmd:g G_i CN EE ED} and, with {opt spatial},
{cmd:g_reg Wg Wg_i n_nbrs CNL EEL EDL}, labeled and formatted. Without
it {cmd:sshare} adds nothing to the dataset; the effects are available
in {cmd:r(effects)}/{cmd:r(units)}.

{phang}{opt prefix(name)} prefixes every generated variable, allowing
several runs to coexist (e.g. {cmd:prefix(chk_)} to re-verify an
imported panel that already carries unprefixed effects). Requires
{opt generate}.

{phang}{opt replace} allows overwriting an existing variable that was
NOT created by {cmd:sshare}. Variables created by the command itself
are always regenerated silently. Requires {opt generate}.


{marker display}{...}
{title:Display options}

{phang}{opt show(list)} chooses the tables: {cmd:growth} (one row per
unit: pairs, levels, G_i), {cmd:regional} (regional, neighborhood and
national growth per unit), {cmd:traditional} (CN EE ED per area),
{cmd:spatial} (CNL EEL EDL per area), {cmd:both} (all six per area),
{cmd:areas} (g, Wg_i, G_i per area). The per-area views print at most
four units; restrict with {opt showif()}.

{phang}{opt showif(exp)} restricts WHICH UNITS the tables show;
benchmarks and computations are untouched. The expression is
evaluated with variable abbreviation off, so a typo raises an error
instead of silently matching another variable.

{phang}{opt areaif(exp)} restricts WHICH AREA ROWS the per-area
tables ({cmd:traditional}, {cmd:spatial}, {cmd:both}, {cmd:areas})
print -- e.g. {cmd:areaif(cve_ent == 19)} for a single state.
Display only, same evaluation rules as {opt showif()}; units left
with no matching areas are skipped. Combine both: {opt showif()}
picks the units, {opt areaif()} the areas.

{phang}
Typing {cmd:sshare} alone replays the tables -- with new
{opt show()}, {opt showif()}, {opt areaif()} or {opt percent} if
desired. The command silently repeats the run from the stored run
record (cheap: no permutations are involved) and rebuilds
{cmd:r(units)} and {cmd:r(effects)} as well.


{marker spatial}{...}
{title:The spatial option and the weight matrix}

{pstd}
W must be BINARY and not row-normalized; the command renormalizes each
neighborhood according to which neighbors carry data. Two routes:

{phang2}(a) Embedded edge list in the dataset characteristics
{cmd:_dta[W_n]}, {cmd:_dta[W_links]} ("i j i j ...", only i<j) and
{cmd:_dta[W_idvar]}. This is how {cmd:capitulo.dta} travels.

{phang2}(b) External {cmd:.mmat} via {opt wfile()}, containing the Mata
object named in {opt wobj()} (default {cmd:Wbin}).

{pstd}
{opt wid()} is the contract between the dataset and W: the row
position. It is validated as an integer in range and unique within
{opt by()} (one row per pair; replicated panel rows are handled by the
long format).


{marker results}{...}
{title:Stored results}

{pstd}{cmd:sshare} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(G)}}national benchmark{p_end}
{synopt:{cmd:r(n_pairs)}}unit-area pairs with a decomposition{p_end}
{synopt:{cmd:r(n_dropped)}}pairs dropped (incomplete){p_end}
{synopt:{cmd:r(t0)}, {cmd:r(t1)}}years{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(ystub)}}variable stub or name{p_end}
{synopt:{cmd:r(benchmark)}}benchmark description{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(units)}}one row per unit: pairs, Y0, Y1, G_i, EE. Row
names = unit code or string.{p_end}
{synopt:{cmd:r(effects)}}one row per decomposed pair: g, G_i, CN, EE,
ED [, Wg, Wg_i, CNL, EEL, EDL, n_nbrs]. Row names = unit:area. Skipped
above 20,000 rows (use {opt generate} there).{p_end}

{pstd}With {opt generate}, the effects are also written as dataset
variables: {cmd:g G_i CN EE ED} and, with {opt spatial},
{cmd:g_reg Wg Wg_i n_nbrs CNL EEL EDL}.


{marker examples}{...}
{title:Examples}

{pstd}Wide data with an embedded W; the dataset stays untouched,
results in {cmd:r()}:{p_end}
{phang2}{cmd:. use data/capitulo.dta, clear}{p_end}
{phang2}{cmd:. sshare empleo, by(unit_key) t0(2018) t1(2023) spatial}{p_end}

{pstd}Same run, effects added as variables:{p_end}
{phang2}{cmd:. sshare empleo, by(unit_key) t0(2018) t1(2023) spatial generate}{p_end}

{pstd}Long panel, effects written on every year row:{p_end}
{phang2}{cmd:. sshare empleo, by(unit_key) t0(2018) t1(2023) year(year) id(cve_ent) spatial generate}{p_end}

{pstd}Inspect one cluster, in percent:{p_end}
{phang2}{cmd:. sshare, show(both) showif(unit_key == 13001) percent}{p_end}

{pstd}Re-verify an imported panel that already has effects:{p_end}
{phang2}{cmd:. sshare empleo, by(unit_key) t0(2018) t1(2023) spatial generate prefix(chk_)}{p_end}
{phang2}{cmd:. assert reldif(chk_EE, EE) < 1e-9 if !missing(EE)}{p_end}

{pstd}Post-process the matrices:{p_end}
{phang2}{cmd:. matlist r(units)}{p_end}


{title:Authors}

{pstd}
Alfonso Mendoza Velazquez and Jose A. Maltes Cuevas. Companion command
for the chapter "La Resiliencia Economica Regional y por Clusteres
Industriales: Analisis Logistico de Cambio y Participacion Espacial
en Mexico"
(Econometria Aplicada con Stata, Stata Press).


{title:References}

{phang}Dunn, E. S. 1960. A statistical and analytical technique for
regional analysis. {it:Papers of the Regional Science Association} 6:
97-112.{p_end}
{phang}Ramajo, J., and M. A. Marquez. 2008. Componentes espaciales en
el modelo shift-share. Una aplicacion al caso de las regiones
peninsulares espanolas. {it:Estadistica Espanola} 50(168):
247-272.{p_end}
{phang}Nazara, S., and G. J. D. Hewings. 2004. Spatial structure and
taxonomy of decomposition in shift-share analysis. {it:Growth and
Change} 35: 476-490.{p_end}

{psee}Also see: {helpb moransub}{p_end}
