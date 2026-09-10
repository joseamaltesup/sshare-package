{smcl}
{* *! version 3.2.0  10sep2026}{...}
{viewerjumpto "Syntax" "moransub##syntax"}{...}
{viewerjumpto "Description" "moransub##description"}{...}
{viewerjumpto "Options" "moransub##options"}{...}
{viewerjumpto "Data formats" "moransub##formats"}{...}
{viewerjumpto "Weight matrices" "moransub##weights"}{...}
{viewerjumpto "Stored results" "moransub##results"}{...}
{viewerjumpto "Examples" "moransub##examples"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col :{cmd:moransub} {hline 2}}Moran's I per unit with option of restricted to the
subgraph of areas with data and permutation based. 
p-value{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:moransub} {varname} {ifin}{cmd:,} {opt by(varname)}
[{it:options}]

{pstd}or, letting the command build the growth rate itself. Wide
format (one column per year: {it:ystub}{it:#}, such as
{cmd:empleo2018} and {cmd:empleo2023}):

{p 8 16 2}
{cmd:moransub} {it:ystub} {ifin}{cmd:,} {opt by(varname)}
{opt t0(#)} {opt t1(#)} [{it:options}]

{pstd}Long format (one row per year):

{p 8 16 2}
{cmd:moransub} {varname} {ifin}{cmd:,} {opt by(varname)}
{opt t0(#)} {opt t1(#)} {opt year(varname)} [{opt id(varlist)}]
[{it:options}]

{pstd}Replay (redisplay the stored table without redoing the
permutations):

{p 8 16 2}
{cmd:moransub} [{cmd:,} {opt lab:el(varname)} {opt notab:le}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt by(varname)}}unit identifier (numeric or string){p_end}

{syntab:Growth rate on the fly}
{synopt:{opt t0(#)}}base year{p_end}
{synopt:{opt t1(#)}}final year; must follow {opt t0()}{p_end}

{syntab:Long format}
{synopt:{opt year(varname)}}year variable; switches to long format{p_end}
{synopt:{opt id(varlist)}}area identifier within {opt by()}; default
{opt wid()} or {cmd:char _dta[W_idvar]}{p_end}

{syntab:Weight matrix}
{synopt:{opt wid(varname)}}row position in W; default
{cmd:char _dta[W_idvar]}{p_end}
{synopt:{opt wfile(filename)}}read W from a {cmd:.mmat} file{p_end}
{synopt:{opt wobj(name)}}Mata object inside {opt wfile()}; default
{cmd:Wbin}{p_end}

{syntab:Inference}
{synopt:{opt np:erm(#)}}permutations; default 9999{p_end}
{synopt:{opt seed(#)}}RNG seed (state restored afterwards); default
12345{p_end}
{synopt:{opt nm:in(#)}}reliability floor for n_eff; default 20{p_end}
{synopt:{opt al:pha(#)}}level for the moran_sig flag; default
0.10{p_end}
{synopt:{opt mode(string)}}{cmd:subgraph} (default) or {cmd:zero}{p_end}

{syntab:Output}
{synopt:{opt pre:fix(name)}}prefix for the generated variables{p_end}
{synopt:{opt lab:el(varname)}}readable unit name{p_end}
{synopt:{opt notab:le}}suppress the table{p_end}
{synopt:{opt replace}}overwrite existing variables NOT created by
{cmd:moransub}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:moransub} computes Moran's I of {varname} for every unit in
{opt by()}, restricting the weight matrix to the SUBGRAPH of areas
with data: missing areas are removed and the neighborhoods are
re-standardized there, instead of being filled with zeros.

{pstd}
Inference uses a permutation test with three p-values. The headline
statistic is the two-tailed {cmd:p_two}. {cmd:p_one} replicates
other statistical packages {cmd:esda.Moran.p_sim}; {cmd:p_abs0} keeps the legacy
|I|-centered-at-zero rule for traceability. {cmd:p_norm} is the
analytic companion, from the normal approximation.

{pstd}
{opt nmin()} does not discard: I is computed for every unit above the
internal floor of 4 areas, and {cmd:reliable} = (n_eff >= nmin) flags
which units support inference. {cmd:moran_sig} = 1 requires
{cmd:p_two} < {opt alpha()} AND reliability. {cmd:sig_level} records
the smallest conventional level passed (1/5/10; 0 = n.s.; missing =
unreliable). The table stars are * p<0.10, ** p<0.05, *** p<0.01,
shown for reliable units only.

{marker formats}{...}
{pstd}
Three ways to supply the rate. {ul:Precomputed}: pass the rate
variable, as always. {ul:Wide}: pass a stub with {opt t0()}/{opt t1()}
and the year columns {it:ystub}{it:t0}, {it:ystub}{it:t1} are read
directly. {ul:Long}: add {opt year()} and the first argument is again
an existing variable, with one row per year; {opt id()} identifies the
area within {opt by()}. The three routes give identical numbers on the
same data (T15 and T16 of the certification script).

{pstd}
Results are replicated on every row of the unit. Panel data are
tolerated: duplicated {opt by()} x {opt wid()} rows (e.g. the long
format written by {helpb sshare}) are accepted when {varname} is
strictly constant within the pair, and each pair enters the test once.

{pstd}
Variables created by {cmd:moransub} carry the characteristic
{cmd:varname[moransub]} and are regenerated silently on the next run;
{opt replace} is needed only for variables the user created. Typing
{cmd:moransub} alone replays the stored table without redoing the
permutations.


{marker options}{...}
{title:Options}

{phang}{opt by(varname)} identifies the unit. String variables are
accepted; the string is used as the display label and as the row name
in {cmd:r(table)}.

{phang}{opt t0(#)} and {opt t1(#)}, always together, ask the command
to build the growth rate ({it:y}{it:t1} - {it:y}{it:t0}) /
{it:y}{it:t0} itself, under the complete-pair rule -- both years valid
AND a positive base, the same rule {helpb sshare} applies -- so the
user does not need a precomputed rate. Incomplete pairs stay missing
and enter the test as no-data areas. The rate lives in a temporary
variable: the dataset is not modified.

{phang}{opt year(varname)} says the pair values are stacked in rows
rather than in columns, and switches the first argument back from a
stub to an existing numeric variable. {opt id(varlist)} names the
variable(s) identifying the area within {opt by()}; it defaults to
{opt wid()} and then to {cmd:char _dta[W_idvar]}. The command requires
a unique row per {opt by()} x {opt id()} at each of t0 and t1; years
outside the requested pair are ignored. Both options describe the long
format and therefore require {opt t0()}/{opt t1()}.

{phang}{opt mode(subgraph)} (default) restricts W to the areas with
data; {opt mode(zero)} fills missing areas with 0 and is kept only to
demonstrate why it should not be used.

{phang}{opt seed(#)} makes the permutations reproducible. The user's
RNG state is saved and restored, so the command leaves no footprint on
later random draws.


{marker weights}{...}
{title:Weight matrices}

{pstd}
W must be BINARY and not row-normalized; {cmd:moransub} standardizes
AFTER restricting to the subgraph. Two routes: (a) the edge list
embedded in the dataset characteristics {cmd:_dta[W_n]},
{cmd:_dta[W_links]}, {cmd:_dta[W_idvar]} (the {cmd:capitulo.dta}
route); (b) an external {cmd:.mmat} via {opt wfile()}. {opt wid()} is
the row position in W and is validated as an integer in range; it is
the only defense against a merge that silently reordered the rows.


{marker results}{...}
{title:Stored results}

{pstd}{cmd:moransub} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(n_stat)}}units with a statistic{p_end}
{synopt:{cmd:r(n_reliable)}}reliable units (n_eff >= nmin){p_end}
{synopt:{cmd:r(n_sig)}}units flagged by moran_sig{p_end}
{synopt:{cmd:r(n_sig1)}, {cmd:r(n_sig5)}, {cmd:r(n_sig10)}}reliable
units significant at 1/5/10%{p_end}
{synopt:{cmd:r(alpha)}, {cmd:r(nperm)}, {cmd:r(nmin)},
{cmd:r(seed)}}settings used{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(mode)}}restriction mode{p_end}
{synopt:{cmd:r(wsource)}}weight matrix provenance{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}one row per unit: n_states n_sub n_eff I E_I
p_norm p_two p_one p_abs0 reliable moran_sig sig_level. Row names =
unit code or string. Skipped above 20,000 rows.{p_end}

{pstd}Generated variables: {cmd:n_states n_sub n_eff I E_I p_norm
p_two p_one p_abs0 reliable moran_sig sig_level}.


{marker examples}{...}
{title:Examples}

{pstd}Chapter pipeline (embedded W, growth rates from sshare):{p_end}
{phang2}{cmd:. use data/capitulo.dta, clear}{p_end}
{phang2}{cmd:. sshare empleo, by(unit_key) t0(2018) t1(2023) spatial notable}{p_end}
{phang2}{cmd:. moransub g, by(unit_key)}{p_end}

{pstd}Same test without a precomputed rate. Wide base -- the stub
plus {opt t0()}/{opt t1()} builds it internally:{p_end}
{phang2}{cmd:. moransub empleo, by(unit_key) t0(2018) t1(2023)}{p_end}

{pstd}Long base -- one row per year, area given by {opt id()}:{p_end}
{phang2}{cmd:. moransub empleo, by(unit_key) t0(2018) t1(2023) year(anio) id(cve_ent)}{p_end}

{pstd}Replay with readable names, no recomputation:{p_end}
{phang2}{cmd:. moransub, label(subcluster_name)}{p_end}

{pstd}Stricter flag and external matrix:{p_end}
{phang2}{cmd:. moransub g, by(unit_key) alpha(0.05) wfile(data/W_rook.mmat) wid(cve_ent)}{p_end}

{pstd}Export the per-unit matrix:{p_end}
{phang2}{cmd:. matlist r(table), format(%9.4f)}{p_end}


{title:Authors}

{pstd}
Alfonso Mendoza Velazquez and Jose A. Maltes Cuevas. Companion command
for the chapter "La Resiliencia Economica Regional y por Clusteres
Industriales: Analisis Logistico de Cambio y Participacion Espacial
en Mexico" (Econometria Aplicada con Stata, Stata Press).


{title:References}

{phang}Cliff, A. D., and J. K. Ord. 1981. {it:Spatial Processes:}
{it:Models and Applications}. London: Pion.{p_end}
{phang}Bivand, R. S., and D. W. S. Wong. 2018. Comparing
implementations of global and local indicators of spatial
association. {it:TEST} 27: 716-748.{p_end}

{psee}Also see: {helpb sshare}{p_end}
