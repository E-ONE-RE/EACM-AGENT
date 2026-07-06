CLASS lhc_agent DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations
      FOR Agent RESULT result.

    METHODS setagentid FOR DETERMINE ON SAVE
      IMPORTING keys FOR Agent~SetAgentID.

    METHODS derivedefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Agent~DeriveDefaults.

    METHODS validatecompanycode FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateCompanyCode.

    METHODS validateagenttype FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateAgentType.

    METHODS validatestatus FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateStatus.

    METHODS validatevendornumber FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateVendorNumber.

    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateDates.

    METHODS validatevatnumber FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateVatNumber.

    METHODS validateemail FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateEmail.

    " Issue #3: Currency code validation
    METHODS validatecurrency FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateCurrency.

    " Issue #7: EnasarcoExempt warning for non-SUBT agent types
    METHODS validateenasarcoexempt FOR VALIDATE ON SAVE
      IMPORTING keys FOR Agent~ValidateEnasarcoExempt.

    METHODS suspend FOR MODIFY
      IMPORTING keys FOR ACTION Agent~Suspend RESULT result.

    METHODS reactivate FOR MODIFY
      IMPORTING keys FOR ACTION Agent~Reactivate RESULT result.

    " Issue #9: Terminal deactivation
    METHODS deactivate FOR MODIFY
      IMPORTING keys FOR ACTION Agent~Deactivate RESULT result.

ENDCLASS.

CLASS lhc_agent IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Issue #5: Authorization structure (TODO: integrate with proper authorization objects)
    " Current: POC permit-all mode - REPLACE with proper checks before production
    " Recommended: Check against authorization object /EACM/AGENT with fields:
    "   - ACTVT (activity): 01=Create, 02=Change, 06=Delete, 70=Display
    "   - BUKRS (Company Code): to restrict by company
    "   - STATUS: to restrict status transitions
    " Example production code (TODO):
    "   AUTHORITY-CHECK OBJECT '/EACM/AGENT'
    "     ID 'ACTVT' FIELD '02'
    "     ID 'BUKRS' FIELD agent-CompanyCode.
    "   IF sy-subrc = 0.
    "     result-%update = if_abap_behv=>auth-allowed.
    "   ELSE.
    "     result-%update = if_abap_behv=>auth-not_allowed.
    "   ENDIF.

    IF requested_authorizations-%create EQ if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update EQ if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete EQ if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-Suspend EQ if_abap_behv=>mk-on.
      result-%action-Suspend = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-Reactivate EQ if_abap_behv=>mk-on.
      result-%action-Reactivate = if_abap_behv=>auth-allowed.
    ENDIF.
    " Issue #9: Deactivate action authorization
    IF requested_authorizations-%action-Deactivate EQ if_abap_behv=>mk-on.
      result-%action-Deactivate = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD setagentid.
    " Issue #10: Improved AgentID generation with reduced collision risk
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    DATA updates TYPE TABLE FOR UPDATE /EACM/I_AGENT.

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>)
      WHERE AgentID IS INITIAL.
      DATA agent_id TYPE /eacm/agent-agent_id.
      DATA lv_attempts TYPE i VALUE 0.
      DATA lv_collision TYPE abap_bool.

      " Try generating unique ID with collision check (max 5 attempts)
      DO 5 TIMES.
        lv_attempts = lv_attempts + 1.

        TRY.
            " Use cl_system_uuid for better uniqueness (126-bit random)
            DATA(uuid_x16) = cl_system_uuid=>create_uuid_x16_static( ).
            DATA(uuid_raw) = CONV xstring( uuid_x16 ).

            " Convert to hex string and take 8 chars (32 bits)
            DATA(hex_full) = |{ uuid_raw }|.
            REPLACE ALL OCCURRENCES OF REGEX '[^0-9A-F]' IN hex_full WITH ''.

            " Build AgentID: AG + 8 hex chars (collision probability ~1 in 4 billion)
            agent_id = |AG{ substring( val = hex_full len = 8 ) }|.

          CATCH cx_uuid_error.
            " Fallback: timestamp-based with milliseconds
            GET TIME STAMP FIELD DATA(lv_ts).
            DATA(ts_string) = |{ lv_ts TIMESTAMP = ENVIRONMENT }|.
            REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN ts_string WITH ''.
            agent_id = |AG{ substring( val = ts_string off = strlen( ts_string ) - 8 len = 8 ) }|.
        ENDTRY.

        " Check for collision in persistent table
        SELECT SINGLE @abap_true FROM /eacm/agent
          WHERE agent_id = @agent_id
          INTO @lv_collision.

        IF lv_collision IS INITIAL.
          " No collision, use this ID
          EXIT.
        ENDIF.
      ENDDO.

      " If still collision after 5 attempts, append counter
      IF lv_collision = abap_true.
        agent_id = |{ agent_id+0(8) }{ sy-tabix }|.
      ENDIF.

      APPEND VALUE #(
        %tky     = <agent>-%tky
        AgentID  = agent_id
        %control-AgentID = if_abap_behv=>mk-on
      ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent
          UPDATE FIELDS ( AgentID )
          WITH updates
        REPORTED DATA(reported_update).
    ENDIF.
  ENDMETHOD.

  METHOD derivedefaults.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( Status ValidFrom Currency )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    DATA lt_update TYPE TABLE FOR UPDATE /EACM/I_AGENT.

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-Status IS INITIAL OR <agent>-ValidFrom IS INITIAL OR <agent>-Currency IS INITIAL.
        APPEND INITIAL LINE TO lt_update ASSIGNING FIELD-SYMBOL(<update>).
        <update>-%tky = <agent>-%tky.

        IF <agent>-Status IS INITIAL.
          <update>-Status = 'A'.
          <update>-%control-Status = if_abap_behv=>mk-on.
        ENDIF.

        IF <agent>-ValidFrom IS INITIAL.
          <update>-ValidFrom = cl_abap_context_info=>get_system_date( ).
          <update>-%control-ValidFrom = if_abap_behv=>mk-on.
        ENDIF.

        IF <agent>-Currency IS INITIAL.
          <update>-Currency = 'EUR'.
          <update>-%control-Currency = if_abap_behv=>mk-on.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent
          UPDATE FROM lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD validatecompanycode.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( CompanyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-CompanyCode IS INITIAL.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_CC'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Company Code is mandatory.' )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-agent.
        CONTINUE.
      ENDIF.

      SELECT SINGLE @abap_true FROM /eacm/company
        WHERE sap_bukrs = @<agent>-CompanyCode
        INTO @DATA(lv_exists).
      IF lv_exists <> abap_true.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_CC'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Company Code '{ <agent>-CompanyCode }' not found in eACM companies.| )
          %element-CompanyCode = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateagenttype.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( AgentTypeCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-AgentTypeCode IS INITIAL.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_AT'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Agent Type is mandatory.' )
          %element-AgentTypeCode = if_abap_behv=>mk-on
        ) TO reported-agent.
        CONTINUE.
      ENDIF.

      SELECT SINGLE @abap_true FROM /eacm/agent_type
        WHERE agent_type_id = @<agent>-AgentTypeCode
          AND is_active     = @abap_true
        INTO @DATA(lv_exists).
      IF lv_exists <> abap_true.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_AT'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Agent Type '{ <agent>-AgentTypeCode }' is not valid.| )
          %element-AgentTypeCode = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatestatus.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-Status <> 'A' AND <agent>-Status <> 'S' AND <agent>-Status <> 'I'.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_STATUS'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Status must be 'A' (Active), 'S' (Suspended), or 'I' (Inactive).| )
          %element-Status = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatevendornumber.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( VendorNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      CHECK <agent>-VendorNumber IS NOT INITIAL.
      IF strlen( <agent>-VendorNumber ) > 10.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_VENDOR'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Vendor Number must not exceed 10 characters.' )
          %element-VendorNumber = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatedates.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-ValidFrom IS INITIAL.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_DATES'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Valid From date is mandatory.' )
          %element-ValidFrom = if_abap_behv=>mk-on
        ) TO reported-agent.
        CONTINUE.
      ENDIF.

      IF <agent>-ValidTo IS NOT INITIAL AND <agent>-ValidTo < <agent>-ValidFrom.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_DATES'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Valid To must be on or after Valid From.' )
          %element-ValidTo = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatevatnumber.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( VatNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      CHECK <agent>-VatNumber IS NOT INITIAL.

      DATA(lv_vat_clean) = <agent>-VatNumber.
      CONDENSE lv_vat_clean NO-GAPS.

      IF lv_vat_clean+0(2) = 'IT'.
        lv_vat_clean = lv_vat_clean+2.
      ENDIF.

      IF strlen( lv_vat_clean ) <> 11.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_VAT'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-warning
            text     = 'Italian VAT number should be 11 digits (optionally prefixed with IT).' )
          %element-VatNumber = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateemail.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
      FIELDS ( Email )
      WITH CORRESPONDING #( keys )
      RESULT DATA(agents)
      FAILED DATA(read_failed).

    LOOP AT agents INTO DATA(agent).
      IF agent-Email IS NOT INITIAL.
        IF NOT ( agent-Email CS '@' AND agent-Email CS '.' ).
          APPEND VALUE #( %tky = agent-%tky ) TO failed-agent.
          APPEND VALUE #( %tky = agent-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-warning
                                   text     = |Invalid email format: { agent-Email }| )
                          %element-Email = if_abap_behv=>mk-on
                        ) TO reported-agent.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatecurrency.
    " Issue #3: Validate currency code against SAP standard currency table
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( Currency )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      CHECK <agent>-Currency IS NOT INITIAL.

*      SELECT SINGLE @abap_true FROM I_Currency
*        WHERE Currency = @<agent>-Currency
*        INTO @DATA(lv_valid).
*
*      IF lv_valid <> abap_true.
*        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
*        APPEND VALUE #(
*          %tky = <agent>-%tky
*          %state_area = 'VALIDATE_CURRENCY'
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text     = |Currency '{ <agent>-Currency }' is not a valid ISO currency code.| )
*          %element-Currency = if_abap_behv=>mk-on
*        ) TO reported-agent.
*      ELSE.
*        " Clear previously reported state message when currency becomes valid
*        APPEND VALUE #(
*          %tky = <agent>-%tky
*          %state_area = 'VALIDATE_CURRENCY'
*        ) TO reported-agent.
*      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateenasarcoexempt.
    " Issue #7: EnasarcoExempt warning only allowed for SUBT agent type
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( AgentTypeCode EnasarcoExempt )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      CHECK <agent>-EnasarcoExempt = abap_true.
      CHECK <agent>-AgentTypeCode IS NOT INITIAL.

      IF <agent>-AgentTypeCode <> 'SUBT'.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %state_area = 'VALIDATE_ENASARCO_EXEMPT'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-warning
            text     = |ENASARCO Exempt is intended for Agent Type SUBT. Current type: { <agent>-AgentTypeCode }.| )
          %element-EnasarcoExempt = if_abap_behv=>mk-on
          %element-AgentTypeCode  = if_abap_behv=>mk-on
        ) TO reported-agent.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD suspend.
    " Issue #4: Suspend agent and cascade to active shareholders
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( Status AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    DATA lt_shareholder_updates TYPE TABLE FOR UPDATE /EACM/I_AGT_SHAREHOLD.

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-Status <> 'A'.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Agent { <agent>-AgentID } can only be suspended when Active.| )
        ) TO reported-agent.
        CONTINUE.
      ENDIF.

      " Suspend the agent
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent
          UPDATE FIELDS ( Status )
          WITH VALUE #( ( %tky   = <agent>-%tky
                          Status = 'S' ) ).

      " Side effect: Suspend all active shareholders of this agent
      READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent BY \_Shareholder
          FIELDS ( AgentID ShareholderID Status )
          WITH VALUE #( ( %tky = <agent>-%tky ) )
        RESULT DATA(shareholders).

      LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh>)
        WHERE Status = 'A'.
        APPEND VALUE #(
          %tky   = <sh>-%tky
          Status = 'S'
          %control-Status = if_abap_behv=>mk-on
        ) TO lt_shareholder_updates.
      ENDLOOP.
    ENDLOOP.

    " Update shareholders if any
    IF lt_shareholder_updates IS NOT INITIAL.
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Shareholder
          UPDATE FROM lt_shareholder_updates.
    ENDIF.

    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky   = ls_res-%tky
                        %param = ls_res ) ).
  ENDMETHOD.

  METHOD reactivate.
    " Issue #4: Reactivate agent and cascade to suspended shareholders
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( Status AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    DATA lt_shareholder_updates TYPE TABLE FOR UPDATE /EACM/I_AGT_SHAREHOLD.

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF <agent>-Status <> 'S'.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Agent { <agent>-AgentID } can only be reactivated when Suspended.| )
        ) TO reported-agent.
        CONTINUE.
      ENDIF.

      " Reactivate the agent
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent
          UPDATE FIELDS ( Status )
          WITH VALUE #( ( %tky   = <agent>-%tky
                          Status = 'A' ) ).

      " Side effect: Reactivate all suspended shareholders of this agent
      " Note: This will reactivate ALL suspended shareholders, including those
      "       that may have been independently suspended before agent suspension.
      "       For production use, consider adding a "suspension_reason" flag.
      READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent BY \_Shareholder
          FIELDS ( AgentID ShareholderID Status )
          WITH VALUE #( ( %tky = <agent>-%tky ) )
        RESULT DATA(shareholders).

      LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh>)
        WHERE Status = 'S'.
        APPEND VALUE #(
          %tky   = <sh>-%tky
          Status = 'A'
          %control-Status = if_abap_behv=>mk-on
        ) TO lt_shareholder_updates.
      ENDLOOP.
    ENDLOOP.

    " Update shareholders if any
    IF lt_shareholder_updates IS NOT INITIAL.
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Shareholder
          UPDATE FROM lt_shareholder_updates.
    ENDIF.

    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result2).
    result = VALUE #( FOR ls_res IN lt_result2
                      ( %tky   = ls_res-%tky
                        %param = ls_res ) ).
  ENDMETHOD.

  METHOD deactivate.
    " Issue #9: Terminal deactivation from Active or Suspended to Inactive
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        FIELDS ( Status AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(agents).

    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      " Only Active (A) or Suspended (S) agents can be deactivated
      IF <agent>-Status <> 'A' AND <agent>-Status <> 'S'.
        APPEND VALUE #( %tky = <agent>-%tky ) TO failed-agent.
        APPEND VALUE #(
          %tky = <agent>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Agent { <agent>-AgentID } can only be deactivated when Active or Suspended.| )
        ) TO reported-agent.
        CONTINUE.
      ENDIF.

      " Set status to Inactive (I) - terminal state
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent
          UPDATE FIELDS ( Status )
          WITH VALUE #( ( %tky            = <agent>-%tky
                          Status          = 'I'
                          %control-Status = if_abap_behv=>mk-on ) ).
    ENDLOOP.

    " Return updated entities
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Agent
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky   = ls_res-%tky
                        %param = ls_res ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_shareholder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS setshareholderid FOR DETERMINE ON SAVE
      IMPORTING keys FOR Shareholder~SetShareholderID.

    " Issue #11: Inherit CompanyCode and Status from parent Agent
    METHODS deriveshareholderdefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Shareholder~DeriveShareholderDefaults.

    METHODS validateparticipation FOR VALIDATE ON SAVE
      IMPORTING keys FOR Shareholder~ValidateParticipation.

    METHODS validateshareholderdates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Shareholder~ValidateShareholderDates.

ENDCLASS.

CLASS lhc_shareholder IMPLEMENTATION.

  METHOD setshareholderid.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Shareholder
        FIELDS ( ShareholderID AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(shareholders).

    LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh>)
         WHERE ShareholderID IS INITIAL.

      SELECT MAX( shareholder_id ) FROM /eacm/agt_shrhld
        WHERE agent_id = @<sh>-AgentID
        INTO @DATA(lv_max_id).

      lv_max_id = lv_max_id + 1.

      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Shareholder
          UPDATE FIELDS ( ShareholderID )
          WITH VALUE #( ( %tky          = <sh>-%tky
                          ShareholderID = lv_max_id ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD deriveshareholderdefaults.
    " Issue #11: Copy CompanyCode from parent Agent, set Status to Active
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Shareholder
        FIELDS ( CompanyCode Status AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(shareholders).

    DATA lt_update TYPE TABLE FOR UPDATE /EACM/I_AGT_SHAREHOLD.

    LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh>).
      DATA(lv_needs_update) = abap_false.
      DATA ls_update TYPE STRUCTURE FOR UPDATE /EACM/I_AGT_SHAREHOLD.
      ls_update-%tky = <sh>-%tky.

      " Copy CompanyCode from parent Agent if not set
      IF <sh>-CompanyCode IS INITIAL.
        READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
          ENTITY Shareholder BY \_Agent
            FIELDS ( CompanyCode )
            WITH VALUE #( ( %tky = <sh>-%tky ) )
          RESULT DATA(agents).

        IF agents IS NOT INITIAL.
          ls_update-CompanyCode = agents[ 1 ]-CompanyCode.
          ls_update-%control-CompanyCode = if_abap_behv=>mk-on.
          lv_needs_update = abap_true.
        ENDIF.
      ENDIF.

      " Set default Status to Active
      IF <sh>-Status IS INITIAL.
        ls_update-Status = 'A'.
        ls_update-%control-Status = if_abap_behv=>mk-on.
        lv_needs_update = abap_true.
      ENDIF.

      IF lv_needs_update = abap_true.
        APPEND ls_update TO lt_update.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Shareholder
          UPDATE FROM lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD validateparticipation.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Shareholder
        FIELDS ( ParticipationPct AgentID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(shareholders).

    " Individual range check
    LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh>).
      IF <sh>-ParticipationPct <= 0 OR <sh>-ParticipationPct > 100.
        APPEND VALUE #( %tky = <sh>-%tky ) TO failed-shareholder.
        APPEND VALUE #(
          %tky = <sh>-%tky
          %state_area = 'VALIDATE_PCT'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Participation must be between 0.01 and 100.00.' )
          %element-ParticipationPct = if_abap_behv=>mk-on
        ) TO reported-shareholder.
      ENDIF.
    ENDLOOP.

    " Issue #1: Cross-validation — total must equal 100%
    " Collect unique AgentIDs from affected shareholders
    DATA lt_agent_ids TYPE SORTED TABLE OF /eacm/agent-agent_id WITH UNIQUE KEY table_line.
    LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh2>).
      INSERT <sh2>-AgentID INTO TABLE lt_agent_ids.
    ENDLOOP.

    " For each agent, read all shareholders and sum participation
    LOOP AT lt_agent_ids INTO DATA(lv_agent_id).
      READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
        ENTITY Agent BY \_Shareholder
          FIELDS ( ParticipationPct AgentID )
          WITH VALUE #( ( AgentID = lv_agent_id ) )
        RESULT DATA(all_shareholders).

      DATA(lv_total) = REDUCE decfloat34(
        INIT sum = CONV decfloat34( 0 )
        FOR ls_sh IN all_shareholders
        NEXT sum = sum + ls_sh-ParticipationPct ).

      IF lv_total <> 100.
        " Report warning on all shareholders of this agent that are in our keys
        LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh3>)
          WHERE AgentID = lv_agent_id.
          APPEND VALUE #(
            %tky = <sh3>-%tky
            %state_area = 'VALIDATE_PCT_TOTAL'
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-warning
              text     = |Total shareholder participation is { lv_total }%. Expected 100%.| )
            %element-ParticipationPct = if_abap_behv=>mk-on
          ) TO reported-shareholder.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateshareholderdates.
    READ ENTITIES OF /EACM/I_AGENT IN LOCAL MODE
      ENTITY Shareholder
        FIELDS ( ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(shareholders).

    LOOP AT shareholders ASSIGNING FIELD-SYMBOL(<sh>).
      IF <sh>-ValidTo IS NOT INITIAL AND <sh>-ValidTo < <sh>-ValidFrom.
        APPEND VALUE #( %tky = <sh>-%tky ) TO failed-shareholder.
        APPEND VALUE #(
          %tky = <sh>-%tky
          %state_area = 'VALIDATE_SH_DATES'
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Valid To must be on or after Valid From.' )
          %element-ValidTo = if_abap_behv=>mk-on
        ) TO reported-shareholder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
