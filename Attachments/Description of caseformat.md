[]{#_top}

<div>

[Home](https://matpower.org/docs/ref/menu5.0.html) \>
[matpower5.0](https://matpower.org/docs/ref/matpower5.0/menu5.0.html) \>
caseformat.m

</div>

# caseformat

## []{#_name}PURPOSE [![\^](./Description%20of%20caseformat_files/up.png){border="0"}](https://matpower.org/docs/ref/matpower5.0/caseformat.html#_top)

::: box
**CASEFORMAT Defines the MATPOWER case file format.**
:::

## []{#_synopsis}SYNOPSIS [![\^](./Description%20of%20caseformat_files/up.png){border="0"}](https://matpower.org/docs/ref/matpower5.0/caseformat.html#_top)

::: box
**This is a script file.**
:::

## []{#_description}DESCRIPTION [![\^](./Description%20of%20caseformat_files/up.png){border="0"}](https://matpower.org/docs/ref/matpower5.0/caseformat.html#_top)

::: fragment
``` comment
CASEFORMAT    Defines the MATPOWER case file format.
   A MATPOWER case file is an M-file or MAT-file that defines or returns
   a struct named mpc, referred to as a "MATPOWER case struct". The fields
   of this struct are baseMVA, bus, gen, branch, and (optional) gencost. With
   the exception of baseMVA, a scalar, each data variable is a matrix, where
   a row corresponds to a single bus, branch, gen, etc. The format of the
   data is similar to the PTI format described in
       http://www.ee.washington.edu/research/pstca/formats/pti.txt
   except where noted. An item marked with (+) indicates that it is included
   in this data but is not part of the PTI format. An item marked with (-) is
   one that is in the PTI format but is not included here. Those marked with
   (2) were added for version 2 of the case file format. The columns for
   each data matrix are given below.

   MATPOWER Case Version Information:
   There are two versions of the MATPOWER case file format. The current
   version of MATPOWER uses version 2 of the MATPOWER case format
   internally, and includes a 'version' field with a value of '2' to make
   the version explicit. Earlier versions of MATPOWER used the version 1
   case format, which defined the data matrices as individual variables,
   as opposed to fields of a struct. Case files in version 1 format with
   OPF data also included an (unused) 'areas' variable. While the version 1
   format has now been deprecated, it is still be handled automatically by
   LOADCASE and SAVECASE which are able to load and save case files in both
   version 1 and version 2 formats.

   See also IDX_BUS, IDX_BRCH, IDX_GEN, IDX_AREA and IDX_COST regarding
   constants which can be used as named column indices for the data matrices.
   Also described in the first three are additional results columns that
   are added to the bus, branch and gen matrices by the power flow and OPF
   solvers.

   The case struct also also allows for additional fields to be included.
   The OPF is designed to recognize fields named A, l, u, H, Cw, N,
   fparm, z0, zl and zu as parameters used to directly extend the OPF
   formulation (see OPF for details). Other user-defined fields may also
   be included and will be automatically loaded by the LOADCASE function
   and, given an appropriate 'savecase' callback function (see
   ADD_USERFCN), saved by the SAVECASE function.

   Bus Data Format
       1   bus number (positive integer)
       2   bus type
               PQ bus          = 1
               PV bus          = 2
               reference bus   = 3
               isolated bus    = 4
       3   Pd, real power demand (MW)
       4   Qd, reactive power demand (MVAr)
       5   Gs, shunt conductance (MW demanded at V = 1.0 p.u.)
       6   Bs, shunt susceptance (MVAr injected at V = 1.0 p.u.)
       7   area number, (positive integer)
       8   Vm, voltage magnitude (p.u.)
       9   Va, voltage angle (degrees)
   (-)     (bus name)
       10  baseKV, base voltage (kV)
       11  zone, loss zone (positive integer)
   (+) 12  maxVm, maximum voltage magnitude (p.u.)
   (+) 13  minVm, minimum voltage magnitude (p.u.)

   Generator Data Format
       1   bus number
   (-)     (machine identifier, 0-9, A-Z)
       2   Pg, real power output (MW)
       3   Qg, reactive power output (MVAr)
       4   Qmax, maximum reactive power output (MVAr)
       5   Qmin, minimum reactive power output (MVAr)
       6   Vg, voltage magnitude setpoint (p.u.)
   (-)     (remote controlled bus index)
       7   mBase, total MVA base of this machine, defaults to baseMVA
   (-)     (machine impedance, p.u. on mBase)
   (-)     (step up transformer impedance, p.u. on mBase)
   (-)     (step up transformer off nominal turns ratio)
       8   status,  >  0 - machine in service
                    <= 0 - machine out of service
   (-)     (% of total VAr's to come from this gen in order to hold V at
               remote bus controlled by several generators)
       9   Pmax, maximum real power output (MW)
       10  Pmin, minimum real power output (MW)
   (2) 11  Pc1, lower real power output of PQ capability curve (MW)
   (2) 12  Pc2, upper real power output of PQ capability curve (MW)
   (2) 13  Qc1min, minimum reactive power output at Pc1 (MVAr)
   (2) 14  Qc1max, maximum reactive power output at Pc1 (MVAr)
   (2) 15  Qc2min, minimum reactive power output at Pc2 (MVAr)
   (2) 16  Qc2max, maximum reactive power output at Pc2 (MVAr)
   (2) 17  ramp rate for load following/AGC (MW/min)
   (2) 18  ramp rate for 10 minute reserves (MW)
   (2) 19  ramp rate for 30 minute reserves (MW)
   (2) 20  ramp rate for reactive power (2 sec timescale) (MVAr/min)
   (2) 21  APF, area participation factor

   Branch Data Format
       1   f, from bus number
       2   t, to bus number
   (-)     (circuit identifier)
       3   r, resistance (p.u.)
       4   x, reactance (p.u.)
       5   b, total line charging susceptance (p.u.)
       6   rateA, MVA rating A (long term rating)
       7   rateB, MVA rating B (short term rating)
       8   rateC, MVA rating C (emergency rating)
       9   ratio, transformer off nominal turns ratio ( = 0 for lines )
           (taps at 'from' bus, impedance at 'to' bus,
            i.e. if r = x = 0, then ratio = Vf / Vt)
       10  angle, transformer phase shift angle (degrees), positive => delay
   (-)     (Gf, shunt conductance at from bus p.u.)
   (-)     (Bf, shunt susceptance at from bus p.u.)
   (-)     (Gt, shunt conductance at to bus p.u.)
   (-)     (Bt, shunt susceptance at to bus p.u.)
       11  initial branch status, 1 - in service, 0 - out of service
   (2) 12  minimum angle difference, angle(Vf) - angle(Vt) (degrees)
   (2) 13  maximum angle difference, angle(Vf) - angle(Vt) (degrees)
           (The voltage angle difference is taken to be unbounded below
            if ANGMIN < -360 and unbounded above if ANGMAX > 360.
            If both parameters are zero, it is unconstrained.)

 (+) Generator Cost Data Format
       NOTE: If gen has ng rows, then the first ng rows of gencost contain
       the cost for active power produced by the corresponding generators.
       If gencost has 2*ng rows then rows ng+1 to 2*ng contain the reactive
       power costs in the same format.
       1   model, 1 - piecewise linear, 2 - polynomial
       2   startup, startup cost in US dollars
       3   shutdown, shutdown cost in US dollars
       4   N, number of cost coefficients to follow for polynomial
           cost function, or number of data points for piecewise linear
       5 and following, parameters defining total cost function f(p),
           units of f and p are $/hr and MW (or MVAr), respectively.
           (MODEL = 1) : p0, f0, p1, f1, ..., pn, fn
               where p0 < p1 < ... < pn and the cost f(p) is defined by
               the coordinates (p0,f0), (p1,f1), ..., (pn,fn) of the
               end/break-points of the piecewise linear cost function
           (MODEL = 2) : cn, ..., c1, c0
               n+1 coefficients of an n-th order polynomial cost function,
               starting with highest order, where cost is
               f(p) = cn*p^n + ... + c1*p + c0

 (+) Area Data Format (deprecated)
     (this data is not used by MATPOWER and is no longer necessary for
      version 2 case files with OPF data).
       1   i, area number
       2   price_ref_bus, reference bus for that area

   See also LOADCASE, SAVECASE, IDX_BUS, IDX_BRCH, IDX_GEN, IDX_AREA
   and IDX_COST.
```
:::

## []{#_cross}CROSS-REFERENCE INFORMATION [![\^](./Description%20of%20caseformat_files/up.png){border="0"}](https://matpower.org/docs/ref/matpower5.0/caseformat.html#_top)

This function calls:

This function is called by:

## []{#_source}SOURCE CODE [![\^](./Description%20of%20caseformat_files/up.png){border="0"}](https://matpower.org/docs/ref/matpower5.0/caseformat.html#_top)

::: fragment
    0001 %CASEFORMAT    Defines the MATPOWER case file format.
    0002 %   A MATPOWER case file is an M-file or MAT-file that defines or returns
    0003 %   a struct named mpc, referred to as a "MATPOWER case struct". The fields
    0004 %   of this struct are baseMVA, bus, gen, branch, and (optional) gencost. With
    0005 %   the exception of baseMVA, a scalar, each data variable is a matrix, where
    0006 %   a row corresponds to a single bus, branch, gen, etc. The format of the
    0007 %   data is similar to the PTI format described in
    0008 %       http://www.ee.washington.edu/research/pstca/formats/pti.txt
    0009 %   except where noted. An item marked with (+) indicates that it is included
    0010 %   in this data but is not part of the PTI format. An item marked with (-) is
    0011 %   one that is in the PTI format but is not included here. Those marked with
    0012 %   (2) were added for version 2 of the case file format. The columns for
    0013 %   each data matrix are given below.
    0014 %
    0015 %   MATPOWER Case Version Information:
    0016 %   There are two versions of the MATPOWER case file format. The current
    0017 %   version of MATPOWER uses version 2 of the MATPOWER case format
    0018 %   internally, and includes a 'version' field with a value of '2' to make
    0019 %   the version explicit. Earlier versions of MATPOWER used the version 1
    0020 %   case format, which defined the data matrices as individual variables,
    0021 %   as opposed to fields of a struct. Case files in version 1 format with
    0022 %   OPF data also included an (unused) 'areas' variable. While the version 1
    0023 %   format has now been deprecated, it is still be handled automatically by
    0024 %   LOADCASE and SAVECASE which are able to load and save case files in both
    0025 %   version 1 and version 2 formats.
    0026 %
    0027 %   See also IDX_BUS, IDX_BRCH, IDX_GEN, IDX_AREA and IDX_COST regarding
    0028 %   constants which can be used as named column indices for the data matrices.
    0029 %   Also described in the first three are additional results columns that
    0030 %   are added to the bus, branch and gen matrices by the power flow and OPF
    0031 %   solvers.
    0032 %
    0033 %   The case struct also also allows for additional fields to be included.
    0034 %   The OPF is designed to recognize fields named A, l, u, H, Cw, N,
    0035 %   fparm, z0, zl and zu as parameters used to directly extend the OPF
    0036 %   formulation (see OPF for details). Other user-defined fields may also
    0037 %   be included and will be automatically loaded by the LOADCASE function
    0038 %   and, given an appropriate 'savecase' callback function (see
    0039 %   ADD_USERFCN), saved by the SAVECASE function.
    0040 %
    0041 %   Bus Data Format
    0042 %       1   bus number (positive integer)
    0043 %       2   bus type
    0044 %               PQ bus          = 1
    0045 %               PV bus          = 2
    0046 %               reference bus   = 3
    0047 %               isolated bus    = 4
    0048 %       3   Pd, real power demand (MW)
    0049 %       4   Qd, reactive power demand (MVAr)
    0050 %       5   Gs, shunt conductance (MW demanded at V = 1.0 p.u.)
    0051 %       6   Bs, shunt susceptance (MVAr injected at V = 1.0 p.u.)
    0052 %       7   area number, (positive integer)
    0053 %       8   Vm, voltage magnitude (p.u.)
    0054 %       9   Va, voltage angle (degrees)
    0055 %   (-)     (bus name)
    0056 %       10  baseKV, base voltage (kV)
    0057 %       11  zone, loss zone (positive integer)
    0058 %   (+) 12  maxVm, maximum voltage magnitude (p.u.)
    0059 %   (+) 13  minVm, minimum voltage magnitude (p.u.)
    0060 %
    0061 %   Generator Data Format
    0062 %       1   bus number
    0063 %   (-)     (machine identifier, 0-9, A-Z)
    0064 %       2   Pg, real power output (MW)
    0065 %       3   Qg, reactive power output (MVAr)
    0066 %       4   Qmax, maximum reactive power output (MVAr)
    0067 %       5   Qmin, minimum reactive power output (MVAr)
    0068 %       6   Vg, voltage magnitude setpoint (p.u.)
    0069 %   (-)     (remote controlled bus index)
    0070 %       7   mBase, total MVA base of this machine, defaults to baseMVA
    0071 %   (-)     (machine impedance, p.u. on mBase)
    0072 %   (-)     (step up transformer impedance, p.u. on mBase)
    0073 %   (-)     (step up transformer off nominal turns ratio)
    0074 %       8   status,  >  0 - machine in service
    0075 %                    <= 0 - machine out of service
    0076 %   (-)     (% of total VAr's to come from this gen in order to hold V at
    0077 %               remote bus controlled by several generators)
    0078 %       9   Pmax, maximum real power output (MW)
    0079 %       10  Pmin, minimum real power output (MW)
    0080 %   (2) 11  Pc1, lower real power output of PQ capability curve (MW)
    0081 %   (2) 12  Pc2, upper real power output of PQ capability curve (MW)
    0082 %   (2) 13  Qc1min, minimum reactive power output at Pc1 (MVAr)
    0083 %   (2) 14  Qc1max, maximum reactive power output at Pc1 (MVAr)
    0084 %   (2) 15  Qc2min, minimum reactive power output at Pc2 (MVAr)
    0085 %   (2) 16  Qc2max, maximum reactive power output at Pc2 (MVAr)
    0086 %   (2) 17  ramp rate for load following/AGC (MW/min)
    0087 %   (2) 18  ramp rate for 10 minute reserves (MW)
    0088 %   (2) 19  ramp rate for 30 minute reserves (MW)
    0089 %   (2) 20  ramp rate for reactive power (2 sec timescale) (MVAr/min)
    0090 %   (2) 21  APF, area participation factor
    0091 %
    0092 %   Branch Data Format
    0093 %       1   f, from bus number
    0094 %       2   t, to bus number
    0095 %   (-)     (circuit identifier)
    0096 %       3   r, resistance (p.u.)
    0097 %       4   x, reactance (p.u.)
    0098 %       5   b, total line charging susceptance (p.u.)
    0099 %       6   rateA, MVA rating A (long term rating)
    0100 %       7   rateB, MVA rating B (short term rating)
    0101 %       8   rateC, MVA rating C (emergency rating)
    0102 %       9   ratio, transformer off nominal turns ratio ( = 0 for lines )
    0103 %           (taps at 'from' bus, impedance at 'to' bus,
    0104 %            i.e. if r = x = 0, then ratio = Vf / Vt)
    0105 %       10  angle, transformer phase shift angle (degrees), positive => delay
    0106 %   (-)     (Gf, shunt conductance at from bus p.u.)
    0107 %   (-)     (Bf, shunt susceptance at from bus p.u.)
    0108 %   (-)     (Gt, shunt conductance at to bus p.u.)
    0109 %   (-)     (Bt, shunt susceptance at to bus p.u.)
    0110 %       11  initial branch status, 1 - in service, 0 - out of service
    0111 %   (2) 12  minimum angle difference, angle(Vf) - angle(Vt) (degrees)
    0112 %   (2) 13  maximum angle difference, angle(Vf) - angle(Vt) (degrees)
    0113 %           (The voltage angle difference is taken to be unbounded below
    0114 %            if ANGMIN < -360 and unbounded above if ANGMAX > 360.
    0115 %            If both parameters are zero, it is unconstrained.)
    0116 %
    0117 % (+) Generator Cost Data Format
    0118 %       NOTE: If gen has ng rows, then the first ng rows of gencost contain
    0119 %       the cost for active power produced by the corresponding generators.
    0120 %       If gencost has 2*ng rows then rows ng+1 to 2*ng contain the reactive
    0121 %       power costs in the same format.
    0122 %       1   model, 1 - piecewise linear, 2 - polynomial
    0123 %       2   startup, startup cost in US dollars
    0124 %       3   shutdown, shutdown cost in US dollars
    0125 %       4   N, number of cost coefficients to follow for polynomial
    0126 %           cost function, or number of data points for piecewise linear
    0127 %       5 and following, parameters defining total cost function f(p),
    0128 %           units of f and p are $/hr and MW (or MVAr), respectively.
    0129 %           (MODEL = 1) : p0, f0, p1, f1, ..., pn, fn
    0130 %               where p0 < p1 < ... < pn and the cost f(p) is defined by
    0131 %               the coordinates (p0,f0), (p1,f1), ..., (pn,fn) of the
    0132 %               end/break-points of the piecewise linear cost function
    0133 %           (MODEL = 2) : cn, ..., c1, c0
    0134 %               n+1 coefficients of an n-th order polynomial cost function,
    0135 %               starting with highest order, where cost is
    0136 %               f(p) = cn*p^n + ... + c1*p + c0
    0137 %
    0138 % (+) Area Data Format (deprecated)
    0139 %     (this data is not used by MATPOWER and is no longer necessary for
    0140 %      version 2 case files with OPF data).
    0141 %       1   i, area number
    0142 %       2   price_ref_bus, reference bus for that area
    0143 %
    0144 %   See also LOADCASE, SAVECASE, IDX_BUS, IDX_BRCH, IDX_GEN, IDX_AREA
    0145 %   and IDX_COST.
    0146 
    0147 %   MATPOWER
    0148 %   $Id: caseformat.m 2166 2013-05-01 19:08:42Z ray $
    0149 %   by Ray Zimmerman, PSERC Cornell
    0150 %   Copyright (c) 1996-2010 by Power System Engineering Research Center (PSERC)
    0151 %
    0152 %   This file is part of MATPOWER.
    0153 %   See http://www.pserc.cornell.edu/matpower/ for more info.
    0154 %
    0155 %   MATPOWER is free software: you can redistribute it and/or modify
    0156 %   it under the terms of the GNU General Public License as published
    0157 %   by the Free Software Foundation, either version 3 of the License,
    0158 %   or (at your option) any later version.
    0159 %
    0160 %   MATPOWER is distributed in the hope that it will be useful,
    0161 %   but WITHOUT ANY WARRANTY; without even the implied warranty of
    0162 %   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    0163 %   GNU General Public License for more details.
    0164 %
    0165 %   You should have received a copy of the GNU General Public License
    0166 %   along with MATPOWER. If not, see <http://www.gnu.org/licenses/>.
    0167 %
    0168 %   Additional permission under GNU GPL version 3 section 7
    0169 %
    0170 %   If you modify MATPOWER, or any covered work, to interface with
    0171 %   other modules (such as MATLAB code and MEX-files) available in a
    0172 %   MATLAB(R) or comparable environment containing parts covered
    0173 %   under other licensing terms, the licensors of MATPOWER grant
    0174 %   you additional permission to convey the resulting work.
:::

------------------------------------------------------------------------

Generated on Mon 26-Jan-2015 15:21:31 by
**[m2html](http://www.artefact.tk/software/matlab/m2html/ "MATPOWER Documentation in HTML")**
© 2005
