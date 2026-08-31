*! version 3.0.3  28aug2026
*! sshare -- Traditional and spatial shift-share decomposition
*!
*! Decomposes the growth of every unit-area pair against the full
*! economy (CN = EE + ED) and, with the spatial option, against the
*! neighborhood defined by a contiguity matrix (CNL = EEL + EDL).
*! The spatial lag averages only over neighbors with data and
*! rescales the neighborhood weights accordingly.
*!
*! SYNTAX (wide):  sshare ystub, by(unit) t0(#) t1(#) [options]
*! SYNTAX (long):  sshare yvar,  by(unit) t0(#) t1(#) year(var)
*!                                [id(varlist)] [options]
*! REPLAY:         sshare [, show() showif() percent notable
*!                           label() arealabel()]
*!
*! RESULTS: r(G) r(n_pairs) r(n_dropped) r(t0) r(t1) and the
*!   matrices r(units) and r(effects). By default no variables are
*!   added to the dataset; the -generate- option adds
*!   g G_i CN EE ED [+ spatial: g_reg Wg Wg_i n_nbrs CNL EEL EDL].
*!   See the help file for the full description.

program define sshare, rclass sortpreserve
    version 16.1

    * ================================================================
    * REPLAY: sshare [, display options] -- silent full recomputation
    * from the stored run record (3.0.0). Effects live in tempvars by
    * default, so there is nothing persistent to redisplay; the
    * recursive call repeats the run (cheap: no permutations) with
    * the fresh display options and rebuilds r(units)/r(effects).
    * ================================================================
    if replay() {
        syntax [, SHOW(string) SHOWif(string) AREAif(string) ///
                  PERCent NOTABle ///
                  LABel(varname) AREAlabel(varname) ]

        local ystub `"`: char _dta[sshare_ystub]'"'
        if `"`ystub'"' == "" {
            display as error "no sshare results in memory;" ///
                " run {helpb sshare} on this dataset first."
            exit 301
        }
        local by_src `"`: char _dta[sshare_by]'"'
        local prefix `"`: char _dta[sshare_prefix]'"'
        local t0     `"`: char _dta[sshare_t0]'"'
        local t1     `"`: char _dta[sshare_t1]'"'
        local spat   `"`: char _dta[sshare_spatial]'"'
        local wid    `"`: char _dta[sshare_wid]'"'
        local year   `"`: char _dta[sshare_year]'"'
        local id     `"`: char _dta[sshare_id]'"'
        local sif    `"`: char _dta[sshare_if]'"'
        local sin    `"`: char _dta[sshare_in]'"'
        local gen    `"`: char _dta[sshare_gen]'"'
        local gbench `"`: char _dta[sshare_gbench]'"'
        local wfile  `"`: char _dta[sshare_wfile]'"'
        local wobjc  `"`: char _dta[sshare_wobj]'"'
        if "`spat'" == "1" local spatial spatial
        else               local spatial

        sshare_chkshow, show(`show') `spatial'

        capture novarabbrev confirm variable `by_src'
        if _rc {
            display as error "the stored by() variable `by_src' is" ///
                " gone; rerun {helpb sshare}."
            exit 111
        }

        local opts by(`by_src') t0(`t0') t1(`t1') `spatial'
        if "`wid'"      != "" local opts `opts' wid(`wid')
        if "`year'"     != "" local opts `opts' year(`year')
        if "`id'"       != "" local opts `opts' id(`id')
        if `"`wfile'"'  != "" local opts `opts' wfile(`wfile')
        if "`wobjc'"    != "" local opts `opts' wobj(`wobjc')
        if `"`gbench'"' != "" local opts `opts' gbench(`gbench')
        if "`gen'" == "1" {
            local opts `opts' generate
            if "`prefix'" != "" local opts `opts' prefix(`prefix')
        }
        if `"`show'"'    != "" local opts `opts' show(`show')
        if `"`showif'"'  != "" local opts `opts' showif(`showif')
        if `"`areaif'"'  != "" local opts `opts' areaif(`areaif')
        if "`percent'"   != "" local opts `opts' percent
        if "`notable'"   != "" local opts `opts' notable
        if "`label'"     != "" local opts `opts' label(`label')
        if "`arealabel'" != "" local opts `opts' arealabel(`arealabel')

        sshare `ystub' `sif' `sin', `opts'
        return add
        exit
    }

    * ================================================================
    * FULL RUN
    * ================================================================
    syntax anything(name=ystub id="base variable stub") [if] [in],  ///
        BY(varname)                                             ///
        T0(integer)                                             ///
        T1(integer)                                             ///
        [ Year(varname numeric)                                 ///
          ID(varlist)                                           ///
          WFile(string)                                         ///
          WID(varname numeric)                                  ///
          WOBJ(name)                                            ///
          SPATIAL                                               ///
          GBench(string)                                        ///
          PREfix(name)                                          ///
          LABel(varname)                                        ///
          AREAlabel(varname)                                    ///
          PERCent                                               ///
          SHOW(string)  /// must be declared BEFORE SHOWif: with
          ///               the longer name first, -syntax- rejects
          ///               a typed show() that precedes showif()
          SHOWif(string)                                        ///
          AREAif(string)                                        ///
          NOTABle                                               ///
          GENerate                                              ///
          replace ]

    if `: word count `ystub'' != 1 {
        display as error "specify exactly one variable stub;" ///
            " see {helpb sshare}."
        exit 198
    }
    if `t0' >= `t1' {
        display as error "t0(`t0') must precede t1(`t1')."
        exit 198
    }
    if "`generate'" == "" & ("`prefix'" != "" | "`replace'" != "") {
        display as error "prefix() and replace require the" ///
            " generate option; see {helpb sshare}."
        exit 198
    }
    if "`wobj'" == "" local wobj "Wbin"

    sshare_chkshow, show(`show') `spatial'

    * -- Data format: wide (default) or long via year() ------------------
    if "`year'" == "" {
        capture confirm numeric variable `ystub'`t0'
        local rc0 = _rc
        capture confirm numeric variable `ystub'`t1'
        if `rc0' | _rc {
            display as error "`ystub'`t0' and/or `ystub'`t1' not found."
            display as error "Wide format expects one column per year" ///
                " (`ystub'`t0', `ystub'`t1')."
            display as error "For long data add year(); see" ///
                " {help sshare##formats:data formats}."
            exit 111
        }
    }
    else {
        capture confirm numeric variable `ystub'
        if _rc {
            display as error "with year(), `ystub' must be an" ///
                " existing numeric variable; see {helpb sshare}."
            exit 111
        }
    }

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

    * -- Long format: resolve the within-unit panel id --------------------
    if "`year'" != "" {
        if "`id'" == "" {
            if "`wid'" != "" local id `wid'
            else {
                local id `"`: char _dta[W_idvar]'"'
                capture confirm numeric variable `id'
                if "`id'" == "" | _rc {
                    display as error "long format needs id(): the" ///
                        " variable(s) identifying the area within"
                    display as error "by() (e.g., the state key);" ///
                        " see {help sshare##formats:data formats}."
                    exit 198
                }
                display as text "Note: id(`id') taken from" ///
                    " char _dta[W_idvar]."
            }
        }
        quietly count if `touse' & missing(`: word 1 of `id'')
        if r(N) > 0 {
            display as text "Note: `r(N)' observation(s) with" ///
                " missing id() excluded."
            markout `touse' `id'
        }
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations satisfy the conditions."
        exit 2000
    }

    * -- Pair variables and the one-row-per-pair tag -----------------------
    * In long format the pair values are replicated on every year row
    * of the unit-area series; `first' tags one row per pair so sums
    * are never inflated by the number of years.
    local popts
    if "`year'" != "" local popts `popts' year(`year')
    if "`id'"   != "" local popts `popts' id(`id')
    tempvar first y0 y1
    sshare_pair, touse(`touse') by(`by') first(`first') ///
        y0(`y0') y1(`y1') ystub(`ystub') t0(`t0') t1(`t1') `popts'

    * -- Effect carriers: r() by default, variables under generate ----------
    * Effects are always computed into the carriers named by the v*
    * locals. Without -generate- those are tempvars (the dataset is
    * left untouched; results live in r()). With -generate- they are
    * the permanent output variables, with the 2.2.0 ownership rule:
    * a variable carrying the char varname[sshare] was created by
    * this command and is regenerated without asking; a variable
    * WITHOUT the mark belongs to the user -- e.g., a g the user
    * created earlier -- and is never overwritten silently. The existence
    * check runs under -novarabbrev-: with variable abbreviation on,
    * a user variable named G_i_pipe would otherwise bind to G_i and
    * trip a spurious rc 110.
    local outvars g G_i CN EE ED
    if "`spatial'" != "" {
        local outvars `outvars' g_reg Wg Wg_i n_nbrs CNL EEL EDL
    }
    if "`generate'" != "" {
        foreach v of local outvars {
            capture novarabbrev confirm variable `prefix'`v'
            if !_rc {
                if `"`: char `prefix'`v'[sshare]'"' != "" | ///
                   "`replace'" != "" {
                    quietly drop `prefix'`v'
                }
                else {
                    display as error "variable `prefix'`v' already" ///
                        " exists and was not created by sshare."
                    display as error "Rename it, run with prefix()," ///
                        " or specify replace; see {helpb sshare}."
                    exit 110
                }
            }
            local v`v' `prefix'`v'
        }
    }
    else {
        foreach v of local outvars {
            tempvar tv`v'
            local v`v' `tv`v''
        }
    }

    * ====================================================================
    * COMPLETE-PAIR RULE
    * A growth rate exists only when both years hold valid data and
    * the base is positive. In many official sources a missing value
    * is a confidentiality suppression, not absence of activity:
    * filling with zeros would fabricate rates.
    * ====================================================================
    tempvar par x0 x1 gall
    quietly generate byte   `par'  = !missing(`y0', `y1') & `y0' > 0
    quietly generate double `x0'   = `y0' if `par'
    quietly generate double `x1'   = `y1' if `par'
    quietly generate double `gall' = (`y1' - `y0') / `y0' if `par'

    * ====================================================================
    * BENCHMARKS -- COMPUTED ON THE FULL BASE, NOT ON if/in
    * G, g_reg and the neighbor lag W.g_i are properties of the whole
    * economy (canonical Ramajo-Marquez style). if/in restricts WHICH
    * rows receive a decomposition, never what they are compared
    * against.
    * ====================================================================
    if `"`gbench'"' == "" {
        quietly summarize `x0' if `first', meanonly
        local Y0nac = r(sum)
        quietly summarize `x1' if `first', meanonly
        local Y1nac = r(sum)
        if `Y0nac' <= 0 {
            display as error "the aggregate of the base year is not" ///
                " positive: benchmark G cannot be computed."
            exit 459
        }
        local G = (`Y1nac' - `Y0nac') / `Y0nac'
        local benchdesc "full economy"

        * Heuristic warning: the command cannot recover rows already
        * removed with -keep-/-drop-; few distinct units suggests a
        * trimmed base and a benchmark that is no longer national.
        tempvar ugrp
        quietly egen `ugrp' = group(`by')
        quietly summarize `ugrp', meanonly
        if r(max) < 10 {
            display as text "Note: benchmark G computed over " ///
                r(max) " units. If the base was trimmed with keep or"
            display as text "drop, G is no longer the full economy's:" ///
                " run on the full base or pass gbench()."
        }
    }
    else {
        capture confirm number `gbench'
        if _rc {
            display as error "gbench() must be a number: '`gbench''."
            exit 198
        }
        local G = `gbench'
        local benchdesc "user-supplied gbench()"
    }

    * -- Unit-level outputs, restricted to if/in ---------------------------
    quietly generate double `vg' = `gall' if `touse'

    tempvar Y0i Y1i
    quietly bysort `by': egen double `Y0i' = total(cond(`first', `x0', .))
    quietly bysort `by': egen double `Y1i' = total(cond(`first', `x1', .))
    quietly generate double `vG_i' = (`Y1i' - `Y0i') / `Y0i' ///
        if `Y0i' > 0 & `touse'

    quietly generate double `vCN' = `vg'   - `G' if `touse'
    quietly generate double `vEE' = `vG_i' - `G' if `touse'
    quietly generate double `vED' = `vg'   - `vG_i' ///
        if `touse'

    capture assert reldif(`vEE' + `vED', `vCN') < 1e-9 ///
        if !missing(`vCN', `vEE', `vED')
    if _rc {
        display as error "the identity CN = EE + ED does not hold."
        display as error "This is a computation error, not a result."
        exit 459
    }

    * ====================================================================
    * SPATIAL BLOCK
    * ====================================================================
    if "`spatial'" != "" {

        * Weight matrix: (a) embedded edge list in the dataset chars
        * (_dta[W_n], _dta[W_links], _dta[W_idvar]) or (b) external
        * .mmat via wfile(). Must be BINARY: sshare_lag() renormalizes
        * each neighborhood according to which neighbors have data.
        local has_char = ("`: char _dta[W_links]'" != "")

        if `"`wfile'"' != "" {
            if `has_char' {
                display as text "Note: the dataset carries an" ///
                    " embedded matrix, but wfile() is used."
            }
            local wbase = subinstr(`"`wfile'"', ".mmat", "", .)
            capture confirm file "`wbase'.mmat"
            if _rc {
                display as error "file `wbase'.mmat not found."
                exit 601
            }
            quietly mata: mata matuse "`wbase'", replace
            capture mata: __ssW = `wobj'
            if _rc {
                display as error "`wbase'.mmat does not contain" ///
                    " the object `wobj'."
                exit 111
            }
            capture mata: mata drop `wobj'
            capture mata: mata drop idb
        }
        else if `has_char' {
            mata: __ssW = sshare_wchar()
        }
        else {
            display as error "spatial requires a weight matrix:" ///
                " none embedded (char _dta[W_links]) and no wfile()."
            display as error "See {help sshare##spatial:the spatial" ///
                " option}."
            exit 198
        }

        mata: st_numscalar("__nW", rows(__ssW))
        local nW = __nW
        scalar drop __nW

        if "`wid'" == "" {
            local wid `"`: char _dta[W_idvar]'"'
            if "`wid'" == "" {
                capture mata: mata drop __ssW
                display as error "wid() is missing and the dataset" ///
                    " declares none (char _dta[W_idvar])."
                exit 198
            }
            capture confirm numeric variable `wid'
            if _rc {
                capture mata: mata drop __ssW
                display as error "the dataset declares wid = `wid'," ///
                    " but it does not exist or is not numeric."
                exit 111
            }
        }

        * Alignment validation over the FULL base (it feeds the lags).
        quietly count if !missing(`wid') & (`wid' != int(`wid') | ///
                                            `wid' < 1 | `wid' > `nW')
        if r(N) > 0 {
            capture mata: mata drop __ssW
            display as error "wid(`wid') has `r(N)' values outside" ///
                " 1..`nW' or non-integer."
            exit 459
        }
        tempvar dup
        quietly duplicates tag `by' `wid' if !missing(`wid') & ///
            `first', generate(`dup')
        quietly count if `dup' > 0 & !missing(`wid') & `first'
        if r(N) > 0 {
            capture mata: mata drop __ssW
            display as error "wid(`wid') repeats within a group of" ///
                " by(`by_src') in `r(N)' pairs."
            display as error "by(`by_src') does not uniquely" ///
                " identify the unit: distinct units share a value."
            capture quietly levelsof `by_src' ///
                if `dup' > 0 & !missing(`wid') & `first', local(badu)
            if !_rc {
                display as error "Shared values (first few):"
                local k 0
                foreach b of local badu {
                    local ++k
                    if `k' > 5 {
                        display as error "  ..."
                        continue, break
                    }
                    display as error `"  `b'"'
                }
            }
            display as error "Use a unique key in by() -- e.g. a" ///
                " code -- and pass the name via label(),"
            display as error "or build one:" ///
                " egen ukey = group(cluster unit), or concatenate" ///
                " the names."
            display as error "See {help sshare##options:options}."
            exit 459
        }

        * Rows without a W position cannot be placed in the matrix:
        * their spatial results stay missing, with a note.
        tempvar sptouse
        quietly generate byte `sptouse' = `touse' & !missing(`wid')
        quietly count if `touse' & missing(`wid')
        if r(N) > 0 {
            display as text "Note: `r(N)' observation(s) with" ///
                " missing `wid': spatial results left missing there."
        }

        * g_reg: the area's AGGREGATE growth over the full base.
        tempvar X0r X1r gregall
        quietly bysort `wid': egen double `X0r' = ///
            total(cond(`first', `x0', .))
        quietly bysort `wid': egen double `X1r' = ///
            total(cond(`first', `x1', .))
        quietly generate double `gregall' = (`X1r' - `X0r') / `X0r' ///
            if `X0r' > 0
        quietly generate double `vg_reg' = `gregall' if `touse'

        foreach v in Wg Wg_i n_nbrs {
            quietly generate double `v`v'' = .
        }

        tempvar allobs
        quietly generate byte `allobs' = !missing(`wid')

        mata: sshare_loop("`by'", "`wid'", "`gall'", "`gregall'",   ///
                           "`vWg' `vWg_i' `vn_nbrs'",                ///
                           "`sptouse'", "`allobs'", __ssW)

        capture mata: mata drop __ssW

        quietly generate double `vCNL' = ///
            `vg'    - `vWg'   if `touse'
        quietly generate double `vEEL' = ///
            `vWg_i' - `vWg'   if `touse'
        quietly generate double `vEDL' = ///
            `vg'    - `vWg_i' if `touse'

        capture assert reldif(`vEEL' + `vEDL', `vCNL') ///
            < 1e-9 if !missing(`vCNL', `vEEL', `vEDL')
        if _rc {
            display as error "the identity CNL = EEL + EDL does" ///
                " not hold."
            exit 459
        }
    }

    * -- Labels, ownership marks, formats (generate only) -------------------
    if "`generate'" != "" {
        label variable `prefix'g   "Growth rate of `ystub', `t0'-`t1'"
        label variable `prefix'G_i "National growth rate of the unit"
        label variable `prefix'CN  "Net change: g - G"
        label variable `prefix'EE  "Structural effect: G_i - G"
        label variable `prefix'ED  "Differential effect: g - G_i"
        if "`spatial'" != "" {
            label variable `prefix'g_reg  "Aggregate growth of the area"
            label variable `prefix'Wg     "W.g: neighbors' aggregate growth"
            label variable `prefix'Wg_i ///
                "W.g_i: unit's growth in the neighbors"
            label variable `prefix'n_nbrs ///
                "Neighbors of the area with data in W.g_i"
            label variable `prefix'CNL "Local net change: g - W.g"
            label variable `prefix'EEL "Local structural effect: W.g_i - W.g"
            label variable `prefix'EDL "Local differential effect: g - W.g_i"
        }
        foreach v of local outvars {
            char `prefix'`v'[sshare] "3.0.3"
        }
        format `prefix'g `prefix'G_i `prefix'CN `prefix'EE `prefix'ED %9.5f
        if "`spatial'" != "" {
            format `prefix'Wg `prefix'Wg_i `prefix'CNL `prefix'EEL ///
                   `prefix'EDL %9.5f
            format `prefix'n_nbrs %4.0f
        }
    }

    * -- Run record: enables replay and documents provenance ----------------
    char _dta[sshare_ystub]     "`ystub'"
    char _dta[sshare_by]        "`by_src'"
    char _dta[sshare_prefix]    "`prefix'"
    char _dta[sshare_t0]        "`t0'"
    char _dta[sshare_t1]        "`t1'"
    char _dta[sshare_G]         "`G'"
    char _dta[sshare_benchmark] "`benchdesc'"
    char _dta[sshare_spatial]   "`=cond("`spatial'"!="","1","0")'"
    char _dta[sshare_wid]       "`wid'"
    char _dta[sshare_year]      "`year'"
    char _dta[sshare_id]        "`id'"
    char _dta[sshare_if]        `"`if'"'
    char _dta[sshare_in]        "`in'"
    char _dta[sshare_t0t1]      "`t0'-`t1'"
    char _dta[sshare_gen]       "`=cond("`generate'"!="","1","0")'"
    char _dta[sshare_gbench]    `"`gbench'"'
    char _dta[sshare_wfile]     `"`wfile'"'
    char _dta[sshare_wobj]      "`wobj'"

    * -- Result matrices ------------------------------------------------------
    * r(units): one row per unit (pairs, levels, G_i, EE).
    * r(effects): one row per decomposed unit-area pair, capped at
    * 20,000 rows. Row names: unit code (and unit:area for effects).
    tempvar tag1 npar
    quietly bysort `touse' `by': generate byte `tag1' = ///
        (_n == 1) & `touse'
    quietly bysort `by': egen int `npar' = ///
        total(cond(`first' & !missing(`vCN'), 1, 0))

    local sorder `by'
    if "`wid'" != "" local sorder `by' `wid'
    sort `sorder'

    tempname UM EM
    quietly count if `tag1'
    if r(N) > 0 & r(N) <= 20000 {
        mata: st_matrix("`UM'", st_data(.,                          ///
            "`npar' `Y0i' `Y1i' `vG_i' `vEE'", "`tag1'"))
        matrix colnames `UM' = pairs Y0 Y1 G_i EE
        mata: sshare_rnames("`UM'", "`by'", "", "`tag1'",          ///
            `bystr', "`by_src'", 1)
        return matrix units = `UM'
    }

    tempvar msel
    quietly generate byte `msel' = `touse' & `first' & ///
        !missing(`vCN')
    quietly count if `msel'
    if r(N) > 0 & r(N) <= 20000 {
        local mv `vg' `vG_i' `vCN' `vEE' `vED'
        local mc g G_i CN EE ED
        if "`spatial'" != "" {
            local mv `mv' `vWg' `vWg_i' `vCNL' ///
                     `vEEL' `vEDL' `vn_nbrs'
            local mc `mc' Wg Wg_i CNL EEL EDL n_nbrs
        }
        mata: st_matrix("`EM'", st_data(., "`mv'", "`msel'"))
        matrix colnames `EM' = `mc'
        mata: sshare_rnames("`EM'", "`by'", "`wid'", "`msel'",      ///
            `bystr', "`by_src'", 0)
        return matrix effects = `EM'
    }
    else if r(N) > 20000 {
        display as text "Note: r(effects) skipped (`r(N)' rows" ///
            " exceed the 20,000-row cap)."
        if "`generate'" == "" {
            display as text "Use the generate option to keep the" ///
                " effects as variables."
        }
    }

    * -- Tables and summary ------------------------------------------------------
    local dopts
    if "`spatial'" != "" {
        local dopts `dopts' spatial vwgi(`vWg_i') vcnl(`vCNL') ///
            veel(`vEEL') vedl(`vEDL')
    }
    if "`wid'"       != ""  local dopts `dopts' wid(`wid')
    if `"`show'"'    != ""  local dopts `dopts' show(`show')
    if `"`showif'"'  != ""  local dopts `dopts' showif(`showif')
    if `"`areaif'"'  != ""  local dopts `dopts' areaif(`areaif')
    if "`percent'"   != ""  local dopts `dopts' percent
    if "`notable'"   != ""  local dopts `dopts' notable
    if "`label'"     != ""  local dopts `dopts' label(`label')
    if "`arealabel'" != ""  local dopts `dopts' arealabel(`arealabel')

    sshare_dsp, touse(`touse') first(`first') byn(`by') ///
        bysrc(`by_src') bystr(`bystr') y0(`y0') y1(`y1') ///
        ystub(`ystub') t0(`t0') t1(`t1') gvalue(`G') ///
        benchdesc(`benchdesc') vg(`vg') vgi(`vG_i') vcn(`vCN') ///
        vee(`vEE') ved(`vED') ///
        genflag(`=cond("`generate'"!="",1,0)') `dopts'

    return scalar G         = `G'
    return scalar n_pairs   = `s(n_pairs)'
    return scalar n_dropped = `s(n_dropped)'
    return scalar t0        = `t0'
    return scalar t1        = `t1'
    return local  ystub     "`ystub'"
    return local  benchmark "`benchdesc'"
end


* ======================================================================
* sshare_chkshow -- validates show() against the spatial option
* ======================================================================
program define sshare_chkshow
    version 16.1
    syntax [, SHOW(string) SPATIAL ]
    if "`show'" == "" exit
    foreach s of local show {
        if !inlist("`s'", "growth", "regional", "traditional", ///
                          "spatial", "both", "areas") {
            display as error "show() invalid: '`s''. Use growth," ///
                " regional, traditional, spatial, both or areas;"
            display as error "see {help sshare##display:display" ///
                " options}."
            exit 198
        }
        if inlist("`s'", "regional", "areas", "spatial", "both") & ///
           "`spatial'" == "" {
            display as error "show(`s') requires the spatial option."
            exit 198
        }
    }
end


* ======================================================================
* sshare_pair -- fills the caller's tempvars y0/y1/first for the
* current data format. Wide: y0/y1 copy the year columns and first=1.
* Long: y0/y1 replicate the t0/t1 values on every row of the by-id
* series and first tags one row per pair.
* ======================================================================
program define sshare_pair, sortpreserve
    version 16.1
    syntax , TOUSE(name) BY(varname) FIRST(name) Y0(name) Y1(name) ///
             YSTUB(string) T0(integer) T1(integer) ///
             [ YEAR(varname) ID(varlist) ]

    if "`year'" == "" {
        quietly generate double `y0' = `ystub'`t0'
        quietly generate double `y1' = `ystub'`t1'
        quietly generate byte   `first' = 1
        exit
    }

    * Long format: one value per by-id-year at t0 and t1.
    tempvar v0 v1 dupy
    quietly generate double `v0' = `ystub' if `year' == `t0'
    quietly generate double `v1' = `ystub' if `year' == `t1'

    quietly duplicates tag `by' `id' `year' ///
        if inlist(`year', `t0', `t1'), generate(`dupy')
    quietly count if `dupy' > 0
    if r(N) > 0 {
        display as error "more than one row per by() x id() x year" ///
            " at `t0'/`t1' (`r(N)' rows);"
        display as error "the long format needs a unique series;" ///
            " see {help sshare##formats:data formats}."
        exit 459
    }

    quietly bysort `by' `id': egen double `y0' = max(`v0')
    quietly bysort `by' `id': egen double `y1' = max(`v1')
    quietly egen byte `first' = tag(`by' `id')

    quietly count if `first' & !missing(`y0')
    if r(N) == 0 {
        display as error "no rows with `year' == `t0' hold data:" ///
            " check t0()/t1() against the panel years."
        exit 2000
    }
end


* ======================================================================
* sshare_dsp -- all displayed output (summary, tables, identities,
* spatial diagnostic). Called by the full run and by replay; leaves
* s(n_pairs) and s(n_dropped) for the caller's returns.
* ======================================================================
program define sshare_dsp, sclass sortpreserve
    version 16.1
    syntax , TOUSE(name) FIRST(name) BYN(varname) BYSRC(string) ///
             BYSTR(integer) Y0(varname) Y1(varname) YSTUB(string) ///
             T0(integer) T1(integer) GVALue(string) ///
             BENCHdesc(string) ///
             VG(varname) VGI(varname) VCN(varname) VEE(varname) ///
             VED(varname) GENFlag(integer) ///
             [ SPATIAL WID(varname) SHOW(string) ///
               VWGI(varname) VCNL(varname) VEEL(varname) ///
               VEDL(varname) ///
               SHOWif(string) AREAif(string) PERCent NOTABle ///
               LABel(varname) AREAlabel(varname) ]

    if "`show'" == "" local show "growth"

    * -- Pair aggregates (cheap; the effects themselves are NOT redone) --
    tempvar par x0 x1 Y0i Y1i npar
    quietly generate byte   `par' = !missing(`y0', `y1') & `y0' > 0
    quietly generate double `x0'  = `y0' if `par'
    quietly generate double `x1'  = `y1' if `par'
    quietly bysort `byn': egen double `Y0i' = ///
        total(cond(`first', `x0', .))
    quietly bysort `byn': egen double `Y1i' = ///
        total(cond(`first', `x1', .))
    quietly bysort `byn': egen int `npar' = ///
        total(cond(`first' & !missing(`vcn'), 1, 0))

    quietly count if `touse' & `first' & !missing(`vcn')
    local npairs = r(N)
    quietly count if `touse' & `first' & missing(`vcn')
    local ndropped = r(N)
    sreturn local n_pairs   `npairs'
    sreturn local n_dropped `ndropped'

    display as text ""
    display as text "National benchmark  G = " as result ///
        %8.4f `gvalue' as text "   (`benchdesc')"
    display as text "Pairs with a decomposition .... " ///
        as result %5.0f `npairs'
    display as text "Dropped (incomplete pair) ..... " ///
        as result %5.0f `ndropped'

    * -- Readable unit descriptor: (1) label(); (2) the string by()
    * itself; (3) the value label of by(); (4) the bare code. --------
    tempvar desc
    quietly generate strL `desc' = ""
    if "`label'" != "" {
        capture confirm string variable `label'
        if !_rc quietly replace `desc' = `label'
        else {
            tempvar decoded
            capture decode `label', generate(`decoded')
            if !_rc quietly replace `desc' = `decoded'
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

    tempvar tag1
    quietly bysort `touse' `byn': generate byte `tag1' = ///
        (_n == 1) & `touse'

    * -- showif(): trims the VIEW only; benchmarks are untouched. -------
    * Variable abbreviation is switched off while it is evaluated so a
    * typo cannot silently bind to an existing variable.
    tempvar showmark
    if `"`showif'"' != "" {
        local vab0 = c(varabbrev)
        set varabbrev off
        capture quietly generate byte `showmark' = ///
            (`showif') & `tag1'
        local rc = _rc
        set varabbrev `vab0'
        if `rc' {
            display as error "showif() is not a valid expression, or"
            display as error "it references a variable that does not" ///
                " exist:"
            display as error "  `showif'"
            display as error "See {help sshare##display:display" ///
                " options}."
            exit `rc'
        }
        quietly count if `showmark'
        if r(N) == 0 {
            display as text "Note: showif() selects no units;" ///
                " unit tables will be empty."
        }
    }
    else quietly generate byte `showmark' = `tag1'

    quietly count if `showmark'
    local n_uni = r(N)

    local vercrec = (strpos("`show'", "growth") > 0)

    if "`notable'" == "" & `vercrec' {
        if `n_uni' > 0 & `n_uni' <= 60 {

            display as text _newline "Decomposition by unit" ///
                _col(52) "`ystub' `t0'-`t1'"
            display as text "Benchmark: `benchdesc'" ///
                _col(52) "G = " as result %8.4f `gvalue'
            if `"`showif'"' != "" {
                display as text "Showing units with: `showif'"
            }
            display as text "{hline 38}{c TT}{hline 39}"
            display as text %-37s "Unit" "{c |}" ///
                _col(41) "Pairs" _col(50) "`t0'" _col(62) "`t1'" ///
                _col(72) "G_i"
            display as text "{hline 38}{c +}{hline 39}"

            preserve
            quietly keep if `showmark'
            sort `byn'
            forvalues i = 1/`=_N' {
                local np = `npar'[`i']
                local a0 = `Y0i'[`i']
                local a1 = `Y1i'[`i']
                local gi = `vgi'[`i']

                local nm = `desc'[`i']
                if `bystr'             local et `"`nm'"'
                else {
                    local u = `byn'[`i']
                    if `"`nm'"' != ""  local et `"`u' `nm'"'
                    else               local et `"`u'"'
                }
                local et = usubstr(`"`et'"', 1, 36)

                display as text %-37s `"`et'"' "{c |}"    ///
                    as result _col(39) %5.0f `np'          ///
                    _col(45) %11.0fc `a0'                  ///
                    _col(57) %11.0fc `a1'                  ///
                    _col(69) %9.4f `gi'
            }
            restore

            display as text "{hline 38}{c BT}{hline 39}"
            display as text "Pairs = areas with data in both years" ///
                " (within if/in)."
            if `genflag' {
                display as text "G_i = the unit's national rate." ///
                    " Per-area effects are in the"
                display as text "generated variables: CN, EE, ED" ///
                    _continue
                if "`spatial'" != "" ///
                    display as text ", CNL, EEL, EDL" _continue
                display as text "."
            }
            else {
                display as text "G_i = the unit's national rate." ///
                    " Per-area effects are in"
                display as text "r(effects); use the generate" ///
                    " option to add them as variables."
            }
        }
        else if `n_uni' > 60 {
            if `genflag' {
                display as text _newline "(`n_uni' units: growth" ///
                    " table omitted. Results are in the generated" ///
                    " variables.)"
            }
            else {
                display as text _newline "(`n_uni' units: growth" ///
                    " table omitted. Results are in r(effects).)"
            }
        }
    }

    * -- show(regional) ---------------------------------------------------
    local verreg = (strpos("`show'", "regional") > 0)

    if "`notable'" == "" & `verreg' & `n_uni' > 0 & `n_uni' <= 60 {

        tempvar mg mwg
        quietly bysort `byn': egen double `mg' = ///
            mean(cond(`first', `vg', .))
        quietly bysort `byn': egen double `mwg' = ///
            mean(cond(`first', `vwgi', .))

        if "`percent'" != "" local esc2 100
        else                 local esc2 1

        display as text _newline ///
            "Regional and neighborhood growth by unit"
        if `"`showif'"' != "" display as text "Units with: `showif'"
        display as text "{hline 74}"
        display as text %-33s "Unit" _col(38) "Regional" ///
            _col(49) "Neighborhood" _col(65) "National"
        display as text %-33s "" _col(40) "(g)" _col(52) "(W.g_i)" ///
            _col(67) "(G_i)"
        display as text "{hline 74}"

        preserve
        quietly keep if `showmark'
        sort `byn'
        forvalues i = 1/`=_N' {
            local nm = `desc'[`i']
            if `bystr'            local et `"`nm'"'
            else {
                local u = `byn'[`i']
                if `"`nm'"' != "" local et `"`u' `nm'"'
                else              local et `"`u'"'
            }
            local et = usubstr(`"`et'"', 1, 32)

            display as text %-33s `"`et'"' as result        ///
                _col(35) %9.2f `esc2'*`mg'[`i']              ///
                _col(48) %9.2f `esc2'*`mwg'[`i']             ///
                _col(62) %9.2f `esc2'*`vgi'[`i']
        }
        restore

        display as text "{hline 74}"
        display as text "Regional and Neighborhood: means over the" ///
            " unit's areas with data."
        display as text "National: the unit's aggregate rate (G_i)."
        if "`percent'" != "" display as text "Figures in percent."
    }

    * -- Per-area tables -----------------------------------------------------
    local porarea 0
    foreach s of local show {
        if inlist("`s'", "traditional", "spatial", "both", "areas") ///
            local porarea 1
    }

    if "`notable'" == "" & `porarea' {

        tempvar adesc
        quietly generate strL `adesc' = ""
        if "`arealabel'" != "" {
            capture confirm string variable `arealabel'
            if !_rc quietly replace `adesc' = `arealabel'
            else {
                tempvar adecoded
                capture decode `arealabel', generate(`adecoded')
                if !_rc quietly replace `adesc' = `adecoded'
            }
        }
        else if "`wid'" != "" {
            local avlab : value label `wid'
            if "`avlab'" != "" {
                tempvar adecoded2
                capture decode `wid', generate(`adecoded2')
                if !_rc quietly replace `adesc' = `adecoded2'
            }
        }

        if "`percent'" != "" local esc 100
        else                 local esc 1

        * areaif(): trims WHICH AREA ROWS the per-area tables print.
        * Display only -- the computation and the benchmarks already
        * happened on the full base. Evaluated with varabbrev off so
        * a typo cannot silently bind to an existing variable.
        tempvar areamark
        if `"`areaif'"' != "" {
            local vab1 = c(varabbrev)
            set varabbrev off
            capture quietly generate byte `areamark' = (`areaif')
            local rc = _rc
            set varabbrev `vab1'
            if `rc' {
                display as error "areaif() is not a valid" ///
                    " expression, or it references a variable"
                display as error "that does not exist:"
                display as error "  `areaif'"
                display as error "See {help sshare##display:display" ///
                    " options}."
                exit `rc'
            }
            quietly count if `areamark' & `touse' & `first' & ///
                !missing(`vg')
            if r(N) == 0 {
                display as text "Note: areaif() matches no areas;" ///
                    " per-area tables will be empty."
            }
            display as text _newline "Areas restricted to: `areaif'"
        }
        else quietly generate byte `areamark' = 1

        quietly levelsof `byn' if `showmark', local(uu)
        local n_bloques : word count `uu'

        if `n_bloques' > 4 {
            display as text _newline "(`n_bloques' units: per-area" ///
                " tables omitted."
            display as text " Restrict with showif() to four or" ///
                " fewer.)"
        }
        else {
            foreach uni of local uu {

                preserve
                quietly keep if `byn' == `uni' & `touse' & `first' & ///
                    !missing(`vg') & `areamark'
                if _N == 0 {
                    restore
                    continue
                }

                local nm = ""
                capture local nm = `desc'[1]
                if `bystr'             local cab `"`nm'"'
                else if `"`nm'"' != "" local cab `"`uni' `nm'"'
                else                   local cab `"`uni'"'

                quietly count if `adesc' != ""
                if r(N) > 0           sort `adesc'
                else if "`wid'" != "" sort `wid'

                foreach s of local show {

                    if "`s'" == "areas" {
                        display as text _newline "Regional," ///
                            " neighborhood and national growth" ///
                            " -- `cab'"
                        display as text "{hline 64}"
                        display as text %-26s "Area" ///
                            _col(31) "Regional" ///
                            _col(42) "Neighborhood" _col(57) "National"
                        display as text %-26s "" _col(34) "(g)" ///
                            _col(45) "(W.g_i)" _col(59) "(G_i)"
                        display as text "{hline 64}"
                        forvalues i = 1/`=_N' {
                            local a = `adesc'[`i']
                            if `"`a'"' == "" & "`wid'" != "" ///
                                local a = `wid'[`i']
                            if `"`a'"' == "" local a "`i'"
                            display as text %-26s ///
                                `"`=usubstr(`"`a'"',1,26)'"'           ///
                                as result                              ///
                                _col(28) %9.2f `esc'*`vg'[`i']         ///
                                _col(41) %9.2f `esc'*`vwgi'[`i']       ///
                                _col(54) %9.2f `esc'*`vgi'[`i']
                        }
                        display as text "{hline 64}"
                        display as text "Regional: the unit's growth" ///
                            " in the area."
                        display as text "Neighborhood: the unit's" ///
                            " growth in the adjacent areas."
                        display as text "National: the unit's" ///
                            " aggregate rate (constant down the" ///
                            " column)."
                        if "`percent'" != "" ///
                            display as text "Figures in percent."
                    }

                    if "`s'" == "both" {
                        display as text _newline "Shift-share -- `cab'"
                        display as text "{hline 79}"
                        display as text _col(28) ///
                            "Traditional shift-share" ///
                            _col(54) "Spatial shift-share"
                        display as text _col(25) "{hline 26}" ///
                            _col(52) "{hline 27}"
                        display as text %-22s "Area"                  ///
                            _col(28) "CN" _col(37) "EE" _col(46) "ED" ///
                            _col(57) "CNL" _col(66) "EEL" ///
                            _col(75) "EDL"
                        display as text "{hline 79}"
                        forvalues i = 1/`=_N' {
                            local a = `adesc'[`i']
                            if `"`a'"' == "" & "`wid'" != "" ///
                                local a = `wid'[`i']
                            if `"`a'"' == "" local a "`i'"
                            display as text %-22s ///
                                `"`=usubstr(`"`a'"',1,22)'"'           ///
                                as result                              ///
                                _col(24) %8.2f `esc'*`vcn'[`i']        ///
                                _col(33) %8.2f `esc'*`vee'[`i']        ///
                                _col(42) %8.2f `esc'*`ved'[`i']        ///
                                _col(53) %8.2f `esc'*`vcnl'[`i']       ///
                                _col(62) %8.2f `esc'*`veel'[`i']       ///
                                _col(71) %8.2f `esc'*`vedl'[`i']
                        }
                        display as text "{hline 79}"
                        display as text "CN = EE + ED (national" ///
                            " benchmark)   CNL = EEL + EDL" ///
                            " (neighborhood)"
                        display as text "EDL - ED = G_i - W.g_i: the" ///
                            " gap between the two benchmarks."
                        if "`percent'" != "" ///
                            display as text "Figures in percent."
                    }

                    if "`s'" == "traditional" {
                        display as text _newline ///
                            "Traditional shift-share -- `cab'"
                        display as text "{hline 55}"
                        display as text %-22s "Area" ///
                            _col(28) "CN" _col(38) "EE" _col(48) "ED"
                        display as text "{hline 55}"
                        forvalues i = 1/`=_N' {
                            local a = `adesc'[`i']
                            if `"`a'"' == "" & "`wid'" != "" ///
                                local a = `wid'[`i']
                            if `"`a'"' == "" local a "`i'"
                            display as text %-22s ///
                                `"`=usubstr(`"`a'"',1,22)'"'           ///
                                as result                              ///
                                _col(24) %9.2f `esc'*`vcn'[`i']        ///
                                _col(34) %9.2f `esc'*`vee'[`i']        ///
                                _col(44) %9.2f `esc'*`ved'[`i']
                        }
                        display as text "{hline 55}"
                        display as text "CN = EE + ED. Benchmark:" ///
                            " the national economy."
                        if "`percent'" != "" ///
                            display as text "Figures in percent."
                    }

                    if "`s'" == "spatial" {
                        display as text _newline ///
                            "Spatial shift-share -- `cab'"
                        display as text "{hline 55}"
                        display as text %-22s "Area" ///
                            _col(27) "CNL" _col(37) "EEL" _col(47) "EDL"
                        display as text "{hline 55}"
                        forvalues i = 1/`=_N' {
                            local a = `adesc'[`i']
                            if `"`a'"' == "" & "`wid'" != "" ///
                                local a = `wid'[`i']
                            if `"`a'"' == "" local a "`i'"
                            display as text %-22s ///
                                `"`=usubstr(`"`a'"',1,22)'"'           ///
                                as result                              ///
                                _col(24) %9.2f `esc'*`vcnl'[`i']       ///
                                _col(34) %9.2f `esc'*`veel'[`i']       ///
                                _col(44) %9.2f `esc'*`vedl'[`i']
                        }
                        display as text "{hline 55}"
                        display as text "CNL = EEL + EDL. Benchmark:" ///
                            " the neighborhood."
                        if "`percent'" != "" ///
                            display as text "Figures in percent."
                    }
                }
                restore
            }
        }
    }

    display as text ""
    display as text "Accounting identity verified:  CN = EE + ED" ///
        "    (g = G + EE + ED)"
    if "`spatial'" != "" {
        display as text "Spatial identity verified:     CNL = EEL" ///
            " + EDL  (g = W.g + EEL + EDL)"
    }

    * -- Spatial diagnostic: informs, does not block ------------------------
    * The decomposition is an identity and holds with or without
    * autocorrelation; the diagnostic tells whether the spatial
    * version ADDS anything. It looks for the unprefixed moran_sig.
    if "`spatial'" != "" {
        capture novarabbrev confirm numeric variable moran_sig
        if !_rc {
            quietly count if `tag1'
            local nu = r(N)
            quietly count if `tag1' & moran_sig == 1
            local ns = r(N)
            display as text ""
            display as text "Spatial diagnostic: " as result `ns' ///
                as text " of " as result `nu' ///
                as text " units with a significant Moran's I"
        }
        else {
            display as text ""
            display as text "No spatial diagnostic in memory: run" ///
                " {helpb moransub} first if you want to"
            display as text "contrast the local effects with" ///
                " Moran's I."
        }
    }
    display as text ""
end


* ======================================================================
* Mata functions -- embedded in the ado-file so they are always
* compiled with the command. -mata set matastrict- inside an
* ado-file is local to the ado-file.
* ======================================================================

version 16.1

mata:
mata set matastrict on

/* --- Rebuild the binary matrix from the dataset characteristics.
       The edge list stores only the i<j pairs; symmetry is restored
       here and indices are validated as integers in range. --------- */
real matrix function sshare_wchar()
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

/* --- Spatial lag with neighborhood renormalization: a neighbor
       without data does NOT enter as zero, it is excluded and the
       remaining weights are rescaled. ------------------------------ */
real colvector function sshare_lag(real colvector v, real matrix W)
{
    real scalar n, i, s
    real colvector res, wi, mask_valid, v_clean
    n = rows(v)
    res = J(n, 1, .)
    mask_valid = (v :!= .)
    v_clean = v
    if (sum(!mask_valid) > 0) {
        v_clean[selectindex(!mask_valid)] = J(sum(!mask_valid), 1, 0)
    }
    for (i = 1; i <= n; i++) {
        wi = W[i,]'
        wi = wi :* mask_valid
        s = sum(wi)
        if (s == 0) continue
        wi = wi :/ s
        res[i] = sum(wi :* v_clean)
    }
    return(res)
}

/* --- Loop over units. Rates and area aggregates come from the FULL
       base (allobs): W.g and W.g_i are benchmarks and must not shrink
       with if/in. Results are written only on the output rows
       (sptouse). Duplicated panel rows repeat identical assignments,
       which is harmless; the pair construction guarantees the value
       is constant within by-area. ---------------------------------- */
void sshare_loop(string scalar byv,   string scalar widv,
                  string scalar gv,    string scalar gregv,
                  string scalar outnames,
                  string scalar sptouse, string scalar allobs,
                  real matrix Wbin)
{
    real matrix A, B, D, V, Wb01
    real colvector units, selB, selD, gfull, greg32, Wg32, Wgi, nv
    real scalar i, n

    n = rows(Wbin)
    Wb01 = (Wbin :> 0)

    A = st_data(., widv + " " + gregv, allobs)
    greg32 = J(n, 1, .)
    greg32[A[., 1]] = A[., 2]
    Wg32 = sshare_lag(greg32, Wbin)

    B = st_data(., byv + " " + widv + " " + gv, allobs)

    D = st_data(., byv + " " + widv, sptouse)
    st_view(V = ., ., outnames, sptouse)

    units = uniqrows(D[., 1])

    for (i = 1; i <= rows(units); i++) {

        selB  = selectindex(B[., 1] :== units[i])
        gfull = J(n, 1, .)
        gfull[B[selB, 2]] = B[selB, 3]

        Wgi = sshare_lag(gfull, Wbin)
        nv  = rowsum(Wb01 :* (gfull :!= .)')

        selD = selectindex(D[., 1] :== units[i])
        V[selD, 1] = Wg32[D[selD, 2]]
        V[selD, 2] = Wgi[D[selD, 2]]
        V[selD, 3] = nv[D[selD, 2]]
    }
}

/* --- Row names for the result matrices.
       unitlevel==1: name = unit label (string by() value or code).
       unitlevel==0: eq = unit label, name = area id (wid) or a
       running index when wid is absent. Names are sanitized to the
       32-character limit with no spaces or colons. ------------------ */
void sshare_rnames(string scalar mname, string scalar byv,
                   string scalar widv,  string scalar sel,
                   real scalar bystr,   string scalar bysrc,
                   real scalar unitlevel)
{
    string colvector eqs, nms
    real scalar i, nr
    string matrix S

    if (bystr) eqs = st_sdata(., bysrc, sel)
    else       eqs = strofreal(st_data(., byv, sel), "%12.0g")
    nr = rows(eqs)

    for (i = 1; i <= nr; i++) {
        eqs[i] = substr(subinstr(subinstr(strtrim(eqs[i]),
                 " ", "_"), ":", "_"), 1, 32)
        if (eqs[i] == "") eqs[i] = "_"
    }

    if (unitlevel) S = (J(nr, 1, ""), eqs)
    else {
        if (widv != "") {
            nms = strofreal(st_data(., widv, sel), "%12.0g")
        }
        else nms = strofreal((1::nr))
        for (i = 1; i <= nr; i++) nms[i] = substr(strtrim(nms[i]), 1, 32)
        S = (eqs, nms)
    }
    st_matrixrowstripe(mname, S)
}

end
