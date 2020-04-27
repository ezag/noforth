(* E112G - For noForth C2553 lp.0, C&V version: Small but fast steps
*)

ecreate sNORM      00 ec, 60 ec, D0 ec,
ecreate sUP        00 ec, A8 ec, FF ec,
ecreate sUPb       10 ec, A8 ec, FF ec,
ecreate sUPF      -10 ec, A8 ec, FF ec,
ecreate sBACKW     10 ec, 60 ec, D0 ec,
ecreate sFORW     -10 ec, 60 ec, D0 ec,

\ Smaller and a little bit faster steps forward
: FSTEP       ( -- )
    sup >rlegs  sbackw >llegs  snorm >rlegs
    supb >llegs  supf >llegs  sforw >llegs ;

\ Smaller and a little bit faster steps backward
: BSTEP       ( -- )
    sup >rlegs  sforw >llegs  snorm >rlegs
    sup >llegs  supb >llegs  sbackw >llegs ;

: FSTEPS  0 ?do  fstep  loop  supf >llegs  snorm >llegs ;   ( u -- )
: BSTEPS  0 ?do  bstep  loop  supb >llegs  snorm >llegs ;   ( u -- )


\ Walk high over very raw surface
ecreate hnorm   00 ec, 30 ec, A0 ec,
ecreate hbackw  10 ec, 30 ec, A0 ec,
ecreate hforw  -10 ec, 30 ec, A0 ec,

: HIGH      hnorm >all ;        \ Stand high on your legs

\ Walk forward with your legs high up
: HSTEP       ( -- )
    sup >rlegs  hbackw >llegs  hnorm >rlegs
    supb >llegs  supf >llegs  hforw >llegs ;

: hsteps      ( u -- )   high  0 ?do  hstep  loop  start ;


\ Slink forward by using a very low profile
ecreate lnorm   00 ec, 90 ec, F0 ec,
ecreate lbackw  10 ec, 90 ec, F0 ec,
ecreate lforw  -10 ec, 90 ec, F0 ec,
ecreate lup     00 ec, B0 ec, F0 ec,
ecreate lupf   -10 ec, B0 ec, F0 ec,
ecreate lupb    10 ec, B0 ec, F0 ec,

\ Stand very low on your legs
: LOW       lnorm >all ;

\ Slink forward
: LSTEPL      ( -- )
    lup >rlegs  lbackw >llegs  lnorm >rlegs
    lupb >llegs  lupf >llegs  lforw >llegs ;

: lsteps      ( u -- )   low  0 ?do  lstepl  loop  start ;

shield elegs\
freeze

\ End