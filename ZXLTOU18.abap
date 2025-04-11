************************************************************************
*                          Tigre/Meta                                  *
************************************************************************
* Autor     : Jaison Carvalho                                          *
* Funcional : Jaison Carvalho                                          *
* Data      : 03.06.2021                                               *
************************************************************************
* Descrição : Efetua a quebra de OTs a partir de parâmetro informado   *
*             pelo usuário para máximo de linhas na OT                 *
************************************************************************
* Alteração :                                                          *
* Autor     :                                                          *
* Funcional :                                                          *
* Chamado   :                                                          *
* Data      :                                                          *
* Descrição :                                                          *
************************************************************************
TYPES:
    BEGIN OF tp_lqua,
      lgnum         TYPE lqua-lgnum,
      lgtyp         TYPE lqua-lgtyp,
      lgpla         TYPE lqua-lgpla,
      lenum         TYPE lqua-lenum,
      gesme         TYPE lqua-gesme,
      verme         TYPE lqua-verme,
     END OF tp_lqua,
    tp_t_lqua       TYPE SORTED TABLE OF tp_lqua
                    WITH NON-UNIQUE KEY lgnum lgtyp lgpla lenum,

    BEGIN OF tp_t331,
      lgnum         TYPE t331-lgnum,
      lgtyp         TYPE t331-lgtyp,
      lenvw         TYPE t331-lenvw,
      stein         TYPE t331-stein,
    END OF tp_t331,
    tp_t_t331       TYPE SORTED TABLE OF tp_t331
                    WITH UNIQUE KEY lgnum lgtyp.


DATA: tl_sval     TYPE STANDARD TABLE OF sval,
      tl_lqua     TYPE tp_t_lqua,
      tl_t331     TYPE tp_t_t331,

      lt_ltap TYPE TABLE OF ltap_vb,
      lt_ltap_fracionado TYPE TABLE OF ltap_vb,

      wl_ltap_pa1 LIKE LINE OF t_ltap_vb,
      wl_sval     TYPE sval,
      wl_lqua     TYPE tp_lqua,

      lv_pooln    TYPE lvs_pooln,
      lv_pooln2   TYPE lvs_pooln,
      lv_cont     TYPE lvs_pooln,
      lv_index    TYPE sy-tabix,
      vl_tabix    TYPE sy-tabix,
      lv_val      TYPE lvs_pooln.

FIELD-SYMBOLS: <fs_ltap> TYPE ltap_vb,
               <fs_ltap_fracionado> TYPE ltap_vb.

CONSTANTS: c_parameter_lgnum TYPE tvarvc-name VALUE 'ZXLTOU18-LGNUM',
           c_parameter_bwlvs TYPE tvarvc-name VALUE 'ZXLTOU18-BWLVS',
           c_type_parameter  TYPE tvarvc-type VALUE 'S'."'P'.

DATA: rg_lgnum TYPE RANGE OF ltap-lgnum,
      rg_bwlvs TYPE RANGE OF ltak-bwlvs.

CALL FUNCTION 'ZMFAB_PARAM_BUSCA_VALORES'
  EXPORTING
    i_name                = c_parameter_lgnum
    i_type                = c_type_parameter
  TABLES
    t_tvarvc_range        = rg_lgnum
  EXCEPTIONS
    nao_encontrado        = 1
    range_nao_informado   = 2
    parametros_incorretos = 3
    OTHERS                = 4.

CALL FUNCTION 'ZMFAB_PARAM_BUSCA_VALORES'
  EXPORTING
    i_name                = c_parameter_bwlvs
    i_type                = c_type_parameter
  TABLES
    t_tvarvc_range        = rg_bwlvs
  EXCEPTIONS
    nao_encontrado        = 1
    range_nao_informado   = 2
    parametros_incorretos = 3
    OTHERS                = 4.

READ TABLE t_ltap_vb INTO wl_ltap_pa1 INDEX 1.

IF  sy-subrc EQ 0 AND rg_lgnum IS NOT INITIAL AND wl_ltap_pa1-lgnum IN rg_lgnum AND rg_bwlvs IS NOT INITIAL AND wl_ltap_pa1-bwlvs IN rg_bwlvs.


  wl_sval-tabname   = 'ZST_LINHA_OT'.
  wl_sval-fieldname = 'ZLINHAS_OT'.
  INSERT wl_sval INTO TABLE tl_sval.

  IMPORT lv_val FROM MEMORY ID 'LV_VAL'.

  IF lv_val IS INITIAL.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'Linhas por OT'(001)
      TABLES
        fields          = tl_sval
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc = 0.

      READ TABLE tl_sval INTO wl_sval INDEX 1.
      IF wl_sval-value IS NOT INITIAL.
        lv_val   = wl_sval-value.
        EXPORT lv_val TO MEMORY ID 'LV_VAL'.
      ENDIF.
    ENDIF.
  ENDIF.

  "Seleciona as quantidades do Pallet na tabela LQUA.
  SELECT lgnum lgtyp lgpla lenum gesme verme
    FROM lqua
    INTO TABLE tl_lqua
    FOR ALL ENTRIES IN t_ltap_vb
   WHERE lgnum = t_ltap_vb-lgnum
     AND lgtyp = t_ltap_vb-vltyp
     AND lgpla = t_ltap_vb-vlpla
     AND lenum = t_ltap_vb-vlenr.

  "Seleciona as informações dos tipos de depósito com controle de UD não blocados
  SELECT lgnum lgtyp lenvw stein
    FROM t331
    INTO TABLE tl_t331
    FOR ALL ENTRIES IN t_ltap_vb
   WHERE lgnum = t_ltap_vb-lgnum
     AND lgtyp = t_ltap_vb-vltyp
     AND lenvw = abap_true
     AND stein <> 'B'.

  lv_pooln = 1.

  lt_ltap[] = t_ltap_vb[].

  LOOP AT lt_ltap ASSIGNING <fs_ltap>.
    lv_index = sy-tabix + 1.
    vl_tabix = sy-tabix.
    "Verifica se o item a ser separado é de um depósito com controle de UD e a quantidade é parcial
    READ TABLE tl_t331 TRANSPORTING NO FIELDS
                              WITH KEY lgnum = <fs_ltap>-lgnum
                                       lgtyp = <fs_ltap>-vltyp BINARY SEARCH.
    IF sy-subrc IS INITIAL.
      READ TABLE tl_lqua INTO wl_lqua
                          WITH KEY lgnum = <fs_ltap>-lgnum
                                   lgtyp = <fs_ltap>-vltyp
                                   lgpla = <fs_ltap>-vlpla
                                   lenum = <fs_ltap>-vlenr BINARY SEARCH.
      IF wl_lqua-gesme <> <fs_ltap>-vsolm OR wl_lqua-gesme <> wl_lqua-verme.
        READ TABLE lt_ltap TRANSPORTING NO FIELDS WITH KEY matnr = <fs_ltap>-matnr
                                                           vltyp = 'PA1'
                                                           queue = <fs_ltap>-queue.
        IF sy-subrc IS INITIAL.
          APPEND <fs_ltap> TO lt_ltap_fracionado.
          DELETE lt_ltap INDEX vl_tabix.
          CONTINUE.
        ENDIF.
      ENDIF.
    ENDIF.

    "Verifica se o item a ser separado é do PA0 e se possui o mesmo material a separar no PA1
    IF <fs_ltap>-vltyp = 'PA0'.
      READ TABLE lt_ltap TRANSPORTING NO FIELDS WITH KEY matnr = <fs_ltap>-matnr
                                                         vltyp = 'PA1'
                                                         queue = <fs_ltap>-queue.
      IF sy-subrc IS INITIAL.
        APPEND <fs_ltap> TO lt_ltap_fracionado.
        DELETE lt_ltap INDEX vl_tabix.
        CONTINUE.
      ENDIF.
    ENDIF.

    lv_cont = lv_cont + 1. CONDENSE lv_cont NO-GAPS. CONDENSE lv_val NO-GAPS.
    lv_pooln2 = <fs_ltap>-pooln.
    <fs_ltap>-pooln = lv_pooln.

    "verifica se o próximo pooln é diferente
    READ TABLE lt_ltap INTO wl_ltap_pa1 INDEX lv_index.
    IF wl_ltap_pa1-pooln <> lv_pooln2.
      CLEAR: lv_cont.
      lv_pooln = lv_pooln + 1.
    ENDIF.

    IF lv_cont = lv_val.
      CLEAR: lv_cont.
      lv_pooln = lv_pooln + 1.
    ENDIF.
  ENDLOOP.

  "Atualiza a info de quebra das OTs
  REFRESH:t_ltap_vb.
  APPEND LINES OF lt_ltap TO t_ltap_vb.

  SORT   lt_ltap BY matnr vltyp.
  SORT   lt_ltap_fracionado BY matnr vltyp.
  "Ordena os Fracionados
  LOOP AT lt_ltap_fracionado ASSIGNING <fs_ltap_fracionado>.
    CONDENSE lv_cont NO-GAPS. CONDENSE lv_val NO-GAPS.
    READ TABLE lt_ltap ASSIGNING <fs_ltap> WITH KEY matnr = <fs_ltap_fracionado>-matnr
                                                    vltyp = 'PA1'
                                                    queue = <fs_ltap_fracionado>-pooln.
    IF sy-subrc = 0.
      <fs_ltap_fracionado>-pooln = <fs_ltap>-pooln.
    ELSE.
      lv_cont = lv_cont + 1.
      IF lv_cont = lv_val.
        CLEAR: lv_cont.
        <fs_ltap_fracionado>-pooln = lv_pooln.
        lv_pooln = lv_pooln + 1.
      ELSE.
        <fs_ltap_fracionado>-pooln = lv_pooln.
      ENDIF.
    ENDIF.
    APPEND <fs_ltap_fracionado> TO t_ltap_vb.
  ENDLOOP.
  SORT t_ltap_vb BY tapos.
ENDIF.
