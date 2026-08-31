*! version 2.2.4  31aug2026
*! moransub -- Moran's I per unit, restricted to the subgraph of
*!             areas with data, with permutation-based inference.
*!
*! Wraps moransub_unit() and its helpers (moransub_I, moransub_p3,
*! moransub_kp, moransub_rownorm), defined in the Mata section at the
*! end of this file.
*!
*! SEMANTICS OF nmin():
*!   Moran's I is computed for EVERY unit above the internal floor of
*!   4 areas; nmin() does not discard, it flags. reliable =
*!   (n_eff >= nmin), and moran_sig requires significance AND
*!   reliability, so small units end with moran_sig = 0 (not missing).
*!
*! OUTPUT VARIABLES:
*!   n_states n_sub n_eff I p_norm p_two p_one p_abs0 I_kp p_kp E_I
*!   reliable moran_sig sig_level
*! Results are also returned in r(), including the r(table) matrix
*! (one row per unit). See the help file for the full description.

program define moransub, rclass sortpreserve
    version 16.1

    * ================================================================
    * REPLAY: moransub [, label() notable] -- no permutations
    * ================================================================
    if replay() {
        syntax [, LABel(varname) NOTABle ]

        local by_src `"`: char _dta[moransub_by]'"'
        if `"`by_src'"' == "" {
            display as error "no moransub results in memory;" ///
                " run {helpb moransub} on this dataset first."
            exit 301
        }
        local prefix `"`: char _dta[moransub_prefix]'"'
        local alpha  `"`: char _dta[moransub_alpha]'"'
        local nmin   `"`: char _dta[moransub_nmin]'"'
        local mode   `"`: char _dta[moransub_mode]'"'
        local nperm  `"`: char _dta[moransub_nperm]'"'
        local wdesc  `"`: char _dta[moransub_w]'"'
        local nlinks `"`: char _dta[moransub_nlinks]'"'
        local wid    `"`: char _dta[moransub_wid]'"'
        local sif    `"`: char _dta[moransub_if]'"'
        local sin    `"`: char _dta[moransub_in]'"'

        * A pre-2.2.0 run leaves moransub_by but not the full replay
        * record; without it the header cannot be reconstructed.
        if `"`nlinks'"' == "" | `"`nperm'"' == "" | `"`wid'"' == "" {
            display as error "the results in memory come from an" ///
                " older moransub; rerun {helpb moransub}."
            exit 301
        }

        capture novarabbrev confirm variable `by_src'
        if _rc {
            display as error "the stored by() variable `by_src' is" ///
                " gone; rerun {helpb moransub}."
            exit 111
        }
        foreach v in n_states n_sub n_eff I E_I p_norm p_two p_one ///
                     p_abs0 I_kp p_kp reliable moran_sig sig_level {
            capture novarabbrev confirm numeric variable `prefix'`v'
            if _rc {
                display as error "`prefix'`v' is gone; rerun" ///
                    " {helpb moransub} to redisplay."
                exit 111
            }
        }

        tempvar touse
        capture mark `touse' `sif' `sin'
        if _rc {
            display as error "the stored if/in condition is no" ///
                " longer valid; rerun {helpb moransub}."
            exit 111
        }

        local bystr 0
        local by `by_src'
        capture confirm string variable `by_src'
        if !_rc {
            local bystr 1
            tempvar byn
            quietly egen long `byn' = group(`by_src')
            local by `byn'
        }
        markout `touse' `by'
        capture confirm numeric variable `wid'
        if !_rc markout `touse' `wid'

        local dopts
        if "`prefix'"  != "" local dopts `dopts' prefix(`prefix')
        if "`label'"   != "" local dopts `dopts' label(`label')
        if "`notable'" != "" local dopts `dopts' notable

        moransub_dsp, touse(`touse') byn(`by') bysrc(`by_src') ///
            bystr(`bystr') nperm(`nperm') alpha(`alpha') ///
            nmin(`nmin') mode(`mode') wdesc(`wdesc') ///
            nlinks(`nlinks') `dopts'

        return scalar n_stat     = `s(n_stat)'
        return scalar n_reliable = `s(n_reliable)'
        return scalar n_sig      = `s(n_sig)'
        return scalar n_sig1     = `s(n_sig1)'
        return scalar n_sig5     = `s(n_sig5)'
        return scalar n_sig10    = `s(n_sig10)'
        return scalar alpha      = `alpha'
        return scalar nperm      = `nperm'
        return scalar nmin       = `nmin'
        return local  mode       "`mode'"
        return local  wsource    "`wdesc'"
        * r(table) is rebuilt only on a full run.
        exit
    }

    * ================================================================
    * FULL RUN
    * ================================================================
    syntax varname(numeric) [if] [in],                  ///
        BY(varname)                                     ///
        [ WFile(string)                                 ///
          WID(varname numeric)                          ///
          WOBJ(name)                                    ///
          NPerm(integer 9999)                           ///
          SEED(integer 12345)                           ///
          NMin(integer 20)                              ///
          ALpha(real 0.10)                              ///
          MODE(string)                                  ///
          PREfix(name)                                  ///
          LABel(varname)                                ///
          NOTABle                                       ///
          replace ]

    local y `varlist'

    * -- Which rows enter -----------------------------------------------
    * novarlist is essential. Without it, marksample drops the rows
    * where `y' is missing, which are precisely the areas without data
    * for the unit. Those rows MUST stay in: Moran's I is a result of
    * the UNIT and has to be written on all of its rows. The missing
    * `y' is not lost: when the vector of length rows(W) is assembled,
    * positions without data stay missing, which is exactly what
    * moransub_unit() expects to restrict the test to the subgraph.
    marksample touse, novarlist

    * -- by(): strings accepted; a numeric key is built internally --------
    local bystr 0
    local by_src `by'
    capture confirm string variable `by'
    if !_rc {
        local bystr 1
        tempvar byn
        quietly egen long `byn' = group(`by')
        local by `byn'
    }
    markout `touse' `by'

    * -- Defaults and option validation ---------------------------------
    if "`mode'" == "" local mode "subgraph"
    if "`wobj'" == "" local wobj "Wbin"

    if !inlist("`mode'", "subgraph", "zero") {
        display as error "mode() invalid: '`mode''. Use subgraph" ///
            " (recommended) or zero; see {helpb moransub}."
        exit 198
    }
    if `nperm' < 99 {
        display as error "nperm() must be at least 99; see" ///
            " {helpb moransub}."
        exit 198
    }
    if `nmin' < 4 {
        display as error "nmin() must be at least 4: moransub_unit()"
        display as error "does not evaluate smaller subgraphs; see" ///
            " {helpb moransub}."
        exit 198
    }
    if `alpha' <= 0 | `alpha' >= 1 {
        display as error "alpha() must lie in the open interval (0,1)."
        exit 198
    }

    * -- wid(): if not declared, take it from the characteristic --------
    * Resolved BEFORE any row is marked out, so that rows with a
    * missing W position are handled the same way on both routes.
    if "`wid'" == "" {
        local wid `"`: char _dta[W_idvar]'"'
        if "`wid'" == "" {
            display as error "wid() is missing: the dataset does not" ///
                " declare which variable"
            display as error "holds the row position in the weight" ///
                " matrix (char _dta[W_idvar]); see {helpb moransub}."
            exit 198
        }
        capture confirm numeric variable `wid'
        if _rc {
            display as error "The dataset declares wid = `wid', but" ///
                " that variable"
            display as error "does not exist or is not numeric."
            exit 111
        }
    }

    * Rows without a W position cannot be placed in the matrix and
    * cannot receive results; they are excluded with an explicit note
    * instead of a cryptic subscript error.
    quietly count if `touse' & missing(`wid')
    if r(N) > 0 {
        display as text "Note: `r(N)' observation(s) with missing" ///
            " `wid' excluded from the test."
        markout `touse' `wid'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "No observations satisfy the conditions:"
        display as error "check if/in and missing values of" ///
            " `by_src' or `wid'."
        exit 2000
    }
    quietly count if `touse' & !missing(`y')
    if r(N) == 0 {
        display as error "`y' is missing in every selected" ///
            " observation: nothing to evaluate."
        exit 2000
    }

    * ====================================================================
    * WEIGHT MATRIX: two routes
    *
    * (a) EMBEDDED in the dataset (chars _dta[W_n], _dta[W_links],
    *     _dta[W_idvar]). The default route.
    * (b) EXTERNAL with wfile(), reading a .mmat.
    *
    * In both cases the matrix must be BINARY and NOT row-normalized:
    * moransub_unit() standardizes AFTER restricting to the subgraph.
    * ====================================================================
    local has_char = ("`: char _dta[W_links]'" != "")
    local wbase ""

    if `"`wfile'"' != "" {
        if `has_char' {
            display as text "Note: the dataset carries an embedded" ///
                " matrix, but wfile() is used."
        }
        local wbase = subinstr(`"`wfile'"', ".mmat", "", .)
        capture confirm file "`wbase'.mmat"
        if _rc {
            display as error "File `wbase'.mmat not found."
            exit 601
        }
        * WARNING: -mata matuse- loads into Mata's GLOBAL space.
        quietly mata: mata matuse "`wbase'", replace
        capture mata: __msW = `wobj'
        if _rc {
            display as error "`wbase'.mmat does not contain the" ///
                " object `wobj'."
            display as error "Inspect it with: mata matdescribe" ///
                " using `wbase'"
            exit 111
        }
        capture mata: mata drop `wobj'
        capture mata: mata drop idb
        local wsource "`wbase'.mmat"
        local wdesc   "wfile(`wbase'.mmat)"
    }
    else if `has_char' {
        mata: __msW = moransub_wchar()
        local wdesc `"`: char _dta[W_desc]'"'
        if `"`wdesc'"' == "" local wdesc "edge list embedded in the dataset"
        local wsource "`wdesc'"
    }
    else {
        display as error "No weight matrix available."
        display as error "The dataset carries no embedded matrix" ///
            " (char _dta[W_links])"
        display as error "and wfile() was not specified; see" ///
            " {help moransub##weights:weight matrices}."
        exit 198
    }

    * -- Structural checks (with cleanup on failure) --------------------
    mata: st_numscalar("__nW",   rows(__msW))
    mata: st_numscalar("__cuad", rows(__msW) == cols(__msW))
    local nW   = __nW
    local cuad = __cuad
    scalar drop __nW __cuad
    if `cuad' == 0 {
        capture mata: mata drop __msW
        display as error "The weight matrix is not square."
        exit 503
    }
    mata: st_numscalar("__nl", sum(__msW :> 0) / 2)
    local nlinks = __nl
    scalar drop __nl

    * -- Alignment validation (the most important one) ------------------
    * wid() is the contract between the dataset and the matrix. A
    * merge that reorders rows leaves everything misaligned WITHOUT
    * raising any error. These tests are the only defense.
    quietly count if `touse' & (`wid' != int(`wid') | ///
                                `wid' < 1 | `wid' > `nW')
    if r(N) > 0 {
        capture mata: mata drop __msW
        display as error "wid(`wid') has `r(N)' values outside" ///
            " 1..`nW' or non-integer."
        display as error "It must be the row position in W."
        exit 459
    }

    * -- Duplicates: panel tolerance -------------------------------------
    * A long panel written by -sshare, year()- replicates the unit-area
    * rate on every year row. Repeated rows are accepted when `y' is
    * STRICTLY constant within by x wid (same value, or all missing):
    * Mata then assigns the same number repeatedly, which is harmless.
    * Mixed missing/value or differing values would make the result
    * order-dependent, so they stop with an error.
    tempvar dup
    quietly duplicates tag `by' `wid' if `touse', generate(`dup')
    quietly count if `dup' > 0 & `touse'
    if r(N) > 0 {
        local ndup = r(N)
        tempvar ymin ymax ycnt gN bad
        quietly bysort `by' `wid': egen double `ymin' = min(`y') ///
            if `touse'
        quietly bysort `by' `wid': egen double `ymax' = max(`y') ///
            if `touse'
        quietly bysort `by' `wid': egen long `ycnt' = count(`y') ///
            if `touse'
        quietly bysort `by' `wid': egen long `gN' = total(`touse')
        quietly generate byte `bad' = `touse' & ///
            ((`ycnt' > 0 & `ycnt' < `gN') | ///
             (`ycnt' > 0 & `ymin' != `ymax'))
        quietly count if `bad'
        if r(N) > 0 {
            capture mata: mata drop __msW
            display as error "`y' varies within by() x wid() in" ///
                " `r(N)' duplicated observations."
            display as error "With panel data, either keep one row" ///
                " per unit-area pair or pass a"
            display as error "variable that is constant within the" ///
                " pair; see {helpb moransub}."
            exit 459
        }
        display as text "Note: panel structure detected (`ndup'" ///
            " duplicated rows per unit-area);"
        display as text "the constant value of each pair is used once."
    }

    * -- Output variables: silent regeneration of OWN variables ------------
    * A variable carrying the char varname[moransub] was created by
    * this command and is regenerated without asking. A variable
    * WITHOUT the mark belongs to the user and is never overwritten
    * silently. The existence check runs under -novarabbrev-: with
    * variable abbreviation on, a user variable named I_pipe would
    * otherwise bind to I and trip a spurious rc 110.
    local mata_out n_states n_sub I p_norm p_two p_one p_abs0 ///
                   I_kp p_kp E_I
    local derived  n_eff reliable moran_sig sig_level

    foreach v in `mata_out' `derived' {
        capture novarabbrev confirm variable `prefix'`v'
        if !_rc {
            if `"`: char `prefix'`v'[moransub]'"' != "" | ///
               "`replace'" != "" {
                quietly drop `prefix'`v'
            }
            else {
                capture mata: mata drop __msW
                display as error "variable `prefix'`v' already" ///
                    " exists and was not created by moransub."
                display as error "Rename it, use prefix(), or" ///
                    " specify replace; see {helpb moransub}."
                exit 110
            }
        }
    }

    local outlist
    foreach v of local mata_out {
        quietly generate double `prefix'`v' = .
        local outlist `outlist' `prefix'`v'
    }

    * -- Computation ------------------------------------------------------
    * The seed is set here: the permutations in moransub_p3() use
    * Stata's generator, so without it replication is not exact. The
    * user's RNG state is saved and restored so the command leaves no
    * footprint on subsequent random draws.
    local rngstate0 `c(rngstate)'
    set seed `seed'

    mata: moransub_loop("`y'", "`by'", "`wid'", "`outlist'", "`touse'", ///
                         __msW, "`mode'", `nperm')

    set rngstate `rngstate0'
    capture mata: mata drop __msW

    * -- Derived flags ----------------------------------------------------
    * n_eff = min(n_states, n_sub). The subgraph can never exceed the
    * areas with data, so the minimum is defensive, not corrective.
    quietly generate int `prefix'n_eff = ///
        min(`prefix'n_states, `prefix'n_sub) if !missing(`prefix'n_sub)
    quietly generate byte `prefix'reliable = ///
        (`prefix'n_eff >= `nmin') if !missing(`prefix'n_eff)

    quietly generate byte `prefix'moran_sig = ///
        (`prefix'p_two < `alpha') & `prefix'reliable ///
        if !missing(`prefix'p_two)

    * sig_level: smallest conventional level passed by the two-tailed
    * permutation p, among RELIABLE units only (1, 5, 10; 0 = not
    * significant at 10%). Missing for unreliable units.
    quietly generate byte `prefix'sig_level = .
    quietly replace `prefix'sig_level = 0 ///
        if `prefix'reliable == 1 & !missing(`prefix'p_two)
    quietly replace `prefix'sig_level = 10 ///
        if `prefix'sig_level == 0  & `prefix'p_two < 0.10
    quietly replace `prefix'sig_level = 5 ///
        if `prefix'sig_level == 10 & `prefix'p_two < 0.05
    quietly replace `prefix'sig_level = 1 ///
        if `prefix'sig_level == 5  & `prefix'p_two < 0.01

    * -- Labels and ownership marks ------------------------------------------
    label variable `prefix'n_states  "Areas with data in the unit"
    label variable `prefix'n_sub     "Effective subgraph size"
    label variable `prefix'n_eff     "min(n_states, n_sub)"
    label variable `prefix'I         ///
        "Moran's I (subgraph of areas with data)"
    label variable `prefix'E_I       "E[I] under H0 = -1/(n-1)"
    label variable `prefix'p_norm    "p, normal approximation"
    label variable `prefix'p_two     ///
        "Permutation p, two-tailed"
    label variable `prefix'p_one     "Permutation p, one-tailed"
    label variable `prefix'p_abs0    "Permutation p, |I| centered at zero"
    label variable `prefix'I_kp      "Kelejian-Prucha I"
    label variable `prefix'p_kp      "Kelejian-Prucha p"
    label variable `prefix'reliable  "1 = n_eff >= `nmin'"
    label variable `prefix'moran_sig ///
        "1 = significant (p_two < `alpha', n >= `nmin')"
    label variable `prefix'sig_level ///
        "Smallest level passed: 1/5/10; 0 = n.s.; . = unreliable"
    foreach v in `mata_out' `derived' {
        char `prefix'`v'[moransub] "2.2.4"
    }

    * -- Run record: provenance + replay -----------------------------------
    char _dta[moransub_w]      "`wsource'"
    if `"`wfile'"' != "" char _dta[moransub_wfile] "`wbase'.mmat"
    else                 char _dta[moransub_wfile] ""
    char _dta[moransub_by]     "`by_src'"
    char _dta[moransub_prefix] "`prefix'"
    char _dta[moransub_alpha]  "`alpha'"
    char _dta[moransub_nmin]   "`nmin'"
    char _dta[moransub_mode]   "`mode'"
    char _dta[moransub_nperm]  "`nperm'"
    char _dta[moransub_seed]   "`seed'"
    char _dta[moransub_wid]    "`wid'"
    char _dta[moransub_nlinks] "`nlinks'"
    char _dta[moransub_if]     `"`if'"'
    char _dta[moransub_in]     "`in'"

    * -- Result matrix r(table): one row per unit ----------------------------
    tempvar tag1
    quietly bysort `touse' `by': generate byte `tag1' = ///
        (_n == 1) & `touse'

    sort `by'
    tempname TB
    quietly count if `tag1'
    if r(N) > 0 & r(N) <= 20000 {
        local tv
        foreach v in n_states n_sub n_eff I E_I p_norm p_two p_one ///
                     p_abs0 I_kp p_kp reliable moran_sig sig_level {
            local tv `tv' `prefix'`v'
        }
        mata: st_matrix("`TB'", st_data(., "`tv'", "`tag1'"))
        matrix colnames `TB' = n_states n_sub n_eff I E_I p_norm ///
            p_two p_one p_abs0 I_kp p_kp reliable moran_sig sig_level
        mata: moransub_rnames("`TB'", "`by'", "`tag1'", ///
            `bystr', "`by_src'")
        return matrix table = `TB'
    }
    else if r(N) > 20000 {
        display as text "Note: r(table) skipped (`r(N)' rows exceed" ///
            " the 20,000-row cap)."
    }

    * -- Table and summary ------------------------------------------------------
    local dopts
    if "`prefix'"  != "" local dopts `dopts' prefix(`prefix')
    if "`label'"   != "" local dopts `dopts' label(`label')
    if "`notable'" != "" local dopts `dopts' notable

    moransub_dsp, touse(`touse') byn(`by') bysrc(`by_src') ///
        bystr(`bystr') nperm(`nperm') alpha(`alpha') nmin(`nmin') ///
        mode(`mode') wdesc(`wdesc') nlinks(`nlinks') `dopts'

    return scalar n_stat     = `s(n_stat)'
    return scalar n_reliable = `s(n_reliable)'
    return scalar n_sig      = `s(n_sig)'
    return scalar n_sig1     = `s(n_sig1)'
    return scalar n_sig5     = `s(n_sig5)'
    return scalar n_sig10    = `s(n_sig10)'
    return scalar alpha      = `alpha'
    return scalar nperm      = `nperm'
    return scalar nmin       = `nmin'
    return scalar seed       = `seed'
    return local  mode       "`mode'"
    return local  wsource    "`wsource'"
end


* ======================================================================
* moransub_dsp -- table and summary. Called by the full run and by
* replay; leaves the counts in s() for the caller's returns.
* ======================================================================
program define moransub_dsp, sclass sortpreserve
    version 16.1
    syntax , TOUSE(name) BYN(varname) BYSRC(string) BYSTR(integer) ///
             NPERM(string) ALPHA(string) NMIN(string) MODE(string) ///
             WDESC(string) NLINKS(string) ///
             [ PREfix(name) LABel(varname) NOTABle ]

    tempvar tag1
    quietly bysort `touse' `byn': generate byte `tag1' = ///
        (_n == 1) & `touse'

    quietly count if `tag1' & !missing(`prefix'I)
    local nstat = r(N)
    quietly count if `tag1' & `prefix'reliable == 1
    local nreliable = r(N)
    quietly count if `tag1' & `prefix'moran_sig == 1
    local n_sig = r(N)
    quietly count if `tag1' & `prefix'reliable == 1 & ///
        `prefix'p_two < 0.01
    local n_sig1 = r(N)
    quietly count if `tag1' & `prefix'reliable == 1 & ///
        `prefix'p_two < 0.05
    local n_sig5 = r(N)
    quietly count if `tag1' & `prefix'reliable == 1 & ///
        `prefix'p_two < 0.10
    local n_sig10 = r(N)

    sreturn local n_stat     `nstat'
    sreturn local n_reliable `nreliable'
    sreturn local n_sig      `n_sig'
    sreturn local n_sig1     `n_sig1'
    sreturn local n_sig5     `n_sig5'
    sreturn local n_sig10    `n_sig10'

    * -- Readable unit descriptor: (1) label(); (2) the string by()
    * itself; (3) the value label of by(); (4) the bare code. --------
    tempvar desc
    quietly generate strL `desc' = ""
    if "`label'" != "" {
        capture confirm string variable `label'
        if !_rc {
            quietly replace `desc' = `label'
        }
        else {
            tempvar decoded
            capture decode `label', generate(`decoded')
            if !_rc quietly replace `desc' = `decoded'
            else {
                display as text "Note: label(`label') is numeric with" ///
                    " no value label; the code is shown."
            }
        }
    }
    else if `bystr' {
        quietly replace `desc' = `bysrc'
    }
    else {
        local vlab : value label `byn'
        if "`vlab'" != "" {
            tempvar decoded2
            capture decode `byn', generate(`decoded2')
            if !_rc quietly replace `desc' = `decoded2'
        }
    }
    quietly count if `desc' != "" & `touse'
    local has_desc = (r(N) > 0)

    * -- Per-unit results table ------------------------------------------------
    * notable suppresses it. It is also skipped when there are too
    * many units: a 200-row table floods the log. To look at a
    * subset, restrict with if (for instance, a single cluster).
    if "`notable'" == "" & `nstat' > 0 & `nstat' <= 60 {

        display as text _newline "Moran's I by unit" ///
            _col(52) "Permutations = " as result `nperm'
        display as text "W: `wdesc'" _col(52) as text ///
            "Links         = " as result `nlinks'
        display as text "Restriction: `mode'" ///
            _col(52) as text "alpha         = " as result %4.2f `alpha'
        display as text "{hline 38}{c TT}{hline 39}"
        if `has_desc' | `bystr' {
            display as text %-37s "Unit" "{c |}" ///
                _col(41) "n" _col(48) "I" _col(58) "E(I)" ///
                _col(66) "p-value" _col(75) "Sig."
        }
        else {
            display as text %-37s abbrev("`bysrc'", 37) "{c |}" ///
                _col(41) "n" _col(48) "I" _col(58) "E(I)" ///
                _col(66) "p-value" _col(75) "Sig."
        }
        display as text "{hline 38}{c +}{hline 39}"

        preserve
        quietly keep if `tag1'
        sort `byn'
        forvalues i = 1/`=_N' {
            local ne = `prefix'n_eff[`i']
            local Iv = `prefix'I[`i']
            local Ev = `prefix'E_I[`i']
            local pv = `prefix'p_two[`i']

            * Code and name together: the code cross-references the
            * other outputs, the name makes the table readable. With
            * a string by(), the string IS the identifier.
            local nm = `desc'[`i']
            if `bystr'             local et `"`nm'"'
            else {
                local u = `byn'[`i']
                if `"`nm'"' != ""  local et `"`u' `nm'"'
                else               local et `"`u'"'
            }
            local et = usubstr(`"`et'"', 1, 36)

            if missing(`Iv') {
                display as text %-37s `"`et'"' "{c |}" ///
                    _col(42) as result "no statistic"
                continue
            }

            * Stars at the 1/5/10% conventional levels, shown only
            * for reliable units; below nmin() the flag replaces them.
            local mk ""
            if `prefix'reliable[`i'] == 1 {
                if      `pv' < 0.01 local mk "***"
                else if `pv' < 0.05 local mk "**"
                else if `pv' < 0.10 local mk "*"
            }
            else local mk "(n<`nmin')"

            display as text %-37s `"`et'"' "{c |}" ///
                as result _col(39) %4.0f `ne'    ///
                _col(44) %9.4f `Iv'              ///
                _col(54) %9.4f `Ev'              ///
                _col(64) %9.4f `pv'              ///
                as text  _col(75) "`mk'"
        }
        restore

        display as text "{hline 38}{c BT}{hline 39}"
        display as text "n = effective subgraph size." ///
            "  Two-tailed permutation p."
        display as text "* p<0.10   ** p<0.05   *** p<0.01" ///
            "  (stars shown for reliable units only)."
        quietly count if `tag1' & `prefix'reliable == 0 & ///
            !missing(`prefix'I)
        if r(N) > 0 {
            display as text "(n<`nmin') flags units whose subgraph" ///
                " falls below nmin()."
        }
    }
    else if "`notable'" == "" & `nstat' > 60 {
        display as text _newline "(`nstat' units: table omitted." ///
            " Results are in the generated variables.)"
    }

    display as text ""
    display as text "Units with a statistic ............ " ///
        as result %5.0f `nstat'
    display as text "Reliable (n_eff >= `nmin') .......... " ///
        as result %5.0f `nreliable'
    display as text "Significant at  1% (reliable) ..... " ///
        as result %5.0f `n_sig1'
    display as text "Significant at  5% (reliable) ..... " ///
        as result %5.0f `n_sig5'
    display as text "Significant at 10% (reliable) ..... " ///
        as result %5.0f `n_sig10'
    display as text "Flagged moran_sig (p < " %4.2f `alpha' ///
        ") ...... " as result %5.0f `n_sig'

    quietly summarize `prefix'n_eff if `tag1' & !missing(`prefix'I)
    if r(N) > 0 {
        display as text ""
        display as text "Subgraph size:  min " ///
            as result %3.0f r(min) ///
            as text "   mean " as result %5.1f r(mean) ///
            as text "   max " as result %3.0f r(max)
    }
    display as text ""
end


* ======================================================================
* Mata functions -- embedded in the ado-file so they are always
* compiled with the command. -mata set matastrict- inside an
* ado-file is local to the ado-file and does not alter the user's
* global setting.
* ======================================================================

version 16.1

mata:
mata set matastrict on

/* --- Rebuild the binary matrix from the dataset characteristics.
       The edge list stores only the i<j pairs; symmetry is restored
       here. Indices are validated as integers in range: a stray
       "1.5" in W_links would otherwise raise a cryptic subscript
       error. ------------------------------------------------------ */
real matrix function moransub_wchar()
{
    string scalar s
    string rowvector tok
    real scalar n, k, i, a, b
    real matrix W

    n = strtoreal(st_global("_dta[W_n]"))
    s = st_global("_dta[W_links]")
    if (n == . | n < 1) {
        errprintf("_dta[W_n] absent or invalid\n")
        exit(198)
    }
    tok = tokens(s)
    k = cols(tok)
    if (mod(k, 2) != 0) {
        errprintf("_dta[W_links] holds an odd number of values\n")
        exit(198)
    }
    W = J(n, n, 0)
    for (i = 1; i <= k; i = i + 2) {
        a = strtoreal(tok[i])
        b = strtoreal(tok[i+1])
        if (a == . | b == . | a != trunc(a) | b != trunc(b) |
            a < 1 | a > n | b < 1 | b > n) {
            errprintf("_dta[W_links] holds an index that is missing,")
            errprintf(" non-integer, or outside 1..%f\n", n)
            exit(198)
        }
        W[a, b] = 1
        W[b, a] = 1
    }
    return(W)
}

/* --- Row standardization (zero rows are left as they are) -------- */
real matrix function moransub_rownorm(real matrix W)
{
    real scalar n, i, s
    real matrix R
    n = rows(W)
    R = W
    for (i = 1; i <= n; i++) {
        s = sum(R[i,])
        if (s > 0) R[i,] = R[i,] :/ s
    }
    return(R)
}

/* --- Global Moran's I + p by normal approximation ----------------- */
real rowvector function moransub_I(real matrix z, real matrix W)
{
    real scalar n, S0, I, EI, S1, S2, m2, m4, k, VI, zI, p
    n   = rows(z)
    S0  = sum(W)
    I   = (n / S0) * (z' * W * z) / (z' * z)
    EI  = -1 / (n - 1)
    S1  = sum((W + W'):^2) / 2
    S2  = sum((rowsum(W) + colsum(W)'):^2)
    m2  = (z'*z) / n
    m4  = sum(z:^4) / n
    k   = m4 / m2^2
    VI  = (n*((n^2-3*n+3)*S1 - n*S2 + 3*S0^2)                    ///
          - k*(n*(n-1)*S1 - 2*n*S2 + 6*S0^2))                    ///
          / ((n-1)*(n-2)*(n-3)*S0^2) - EI^2
    zI  = (I - EI) / sqrt(VI)
    p   = 2 * (1 - normal(abs(zI)))
    return((I, p))
}

/* --- The THREE permutation p-values from ONE simulation run.
       p_two   |I_perm - mu| >= |I_obs - mu|, mu = simulated mean.
               Two-tailed, CORRECT: the null is centered at
               E[I] = -1/(n-1), not at zero (Cliff & Ord 1981).
       p_one   smaller tail (= esda.Moran.p_sim in PySAL).
       p_abs0  |I| centered at zero (legacy rule, kept for
               traceability). --------------------------------------- */
real rowvector function moransub_p3(real matrix z, real matrix W,
                                    real scalar I_obs, real scalar nperm)
{
    real scalar n, S0, i, mu, ge, le
    real colvector sims
    real matrix zp
    n  = rows(z)
    S0 = sum(W)
    sims = J(nperm, 1, .)
    for (i = 1; i <= nperm; i++) {
        zp      = jumble(z)
        sims[i] = (n / S0) * (zp' * W * zp) / (zp' * zp)
    }
    mu = mean(sims)
    ge = sum(sims :>= I_obs)
    le = nperm - ge
    return(((sum(abs(sims :- mu) :>= abs(I_obs - mu)) + 1) / (nperm + 1),
            (min((ge, le))                            + 1) / (nperm + 1),
            (sum(abs(sims)       :>= abs(I_obs))      + 1) / (nperm + 1)))
}

/* --- Kelejian-Prucha with sign; robustness column ----------------- */
real rowvector function moransub_kp(real colvector u, real matrix W)
{
    real scalar n, s2, tr, I
    n  = rows(u)
    s2 = (u' * u) / n
    tr = trace((W' + W) * W)
    if (s2 == 0 | tr <= 0) return((., .))
    I = (u' * W * u) / (s2 * sqrt(tr))
    return((I, 2 * (1 - normal(abs(I)))))
}

/* --- The full test for ONE unit.
       Receives the vector of length rows(Wbin) with MISSING where
       there is no data (not zeros) and the BINARY, non-normalized W,
       so it can restrict to the subgraph and re-standardize there.
       Returns: 1 n_used, 2 I, 3 p_norm, 4 p_two, 5 p_one,
                6 p_abs0, 7 I_kp, 8 p_kp, 9 E_I.
       In "subgraph" mode it also drops areas that, within the
       subset, are left without any neighbor with data. Dropping an
       isolated node cannot disconnect the others, so one pass
       suffices. ---------------------------------------------------- */
real rowvector function moransub_unit(real colvector y, real matrix Wbin,
                                        string scalar mode,
                                        real scalar nperm)
{
    real colvector idx, sel, z
    real matrix Ws, Wr
    real rowvector r1, r3, rk
    real scalar n

    if (mode == "subgraph") {
        idx = selectindex(y :!= .)
        if (rows(idx) < 4) return(J(1, 9, .))
        Ws  = Wbin[idx, idx]
        sel = selectindex(rowsum(Ws) :> 0)
        if (rows(sel) < 4) return(J(1, 9, .))
        idx = idx[sel]
        Ws  = Wbin[idx, idx]
        z   = y[idx]
    }
    else {
        z  = editmissing(y, 0)
        Ws = Wbin
    }

    n = rows(z)
    if (variance(z) == 0) return(J(1, 9, .))
    Wr = moransub_rownorm(Ws)
    z  = z :- mean(z)

    r1 = moransub_I(z, Wr)
    r3 = moransub_p3(z, Wr, r1[1,1], nperm)
    rk = moransub_kp(z, Wr)
    return((n, r1[1,1], r1[1,2], r3[1,1], r3[1,2], r3[1,3],
            rk[1,1], rk[1,2], -1 / (n - 1)))
}

/* --- Loop over units. Assembles the vector of length rows(W) from
       the dataset rows, using wid as the row position, and writes
       the results back. It does NOT apply nmin: the size restriction
       is handled by the reliable flag. Duplicated panel rows repeat
       identical assignments (the ado has already verified constancy
       within by x wid), which is harmless. -------------------------- */
void moransub_loop(string scalar yv,   string scalar byv,
                    string scalar widv, string scalar outnames,
                    string scalar touse,
                    real matrix Wbin,   string scalar mode,
                    real scalar nperm)
{
    real matrix D, V
    real colvector units, sel, yfull
    real rowvector r
    real scalar i, n, ndata

    D = st_data(., yv + " " + byv + " " + widv, touse)
    st_view(V = ., ., outnames, touse)

    units = uniqrows(D[., 2])
    n = rows(Wbin)

    for (i = 1; i <= rows(units); i++) {

        sel = selectindex(D[., 2] :== units[i])

        /* Vector of length n with MISSING where there is no row. The
           position comes from wid: this is why its validation in the
           ado is the defense against a reordering merge.            */
        yfull = J(n, 1, .)
        yfull[D[sel, 3]] = D[sel, 1]

        ndata = sum(yfull :!= .)
        if (ndata < 4) continue

        r = moransub_unit(yfull, Wbin, mode, nperm)

        /* Column 1: areas with data before restricting.
           Columns 2 to 10: what moransub_unit() returns.
           The result belongs to the unit, so it is replicated on all
           of its rows to survive later merges.                      */
        V[sel, .] = J(rows(sel), 1, 1) * (ndata, r)
    }
}

/* --- Row names for r(table): the unit label (string by() value or
       the numeric code), sanitized to the 32-character limit with no
       spaces or colons. ---------------------------------------------- */
void moransub_rnames(string scalar mname, string scalar byv,
                     string scalar sel,   real scalar bystr,
                     string scalar bysrc)
{
    string colvector nms
    real scalar i, nr
    string matrix S

    if (bystr) nms = st_sdata(., bysrc, sel)
    else       nms = strofreal(st_data(., byv, sel), "%12.0g")
    nr = rows(nms)
    for (i = 1; i <= nr; i++) {
        nms[i] = substr(subinstr(subinstr(strtrim(nms[i]),
                 " ", "_"), ":", "_"), 1, 32)
        if (nms[i] == "") nms[i] = "_"
    }
    S = (J(nr, 1, ""), nms)
    st_matrixrowstripe(mname, S)
}

end
