CLASS /eacm/cl_fill_agent DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS fill_agent_types
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    METHODS fill_agents
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    METHODS fill_shareholders
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.



CLASS /eacm/cl_fill_agent IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    fill_agent_types( out ).
    fill_agents( out ).
    fill_shareholders( out ).
    out->write( |Mock data load complete.| ).
  ENDMETHOD.


  METHOD fill_agent_types.
    DATA lt_types TYPE STANDARD TABLE OF /eacm/agent_type.

    SELECT COUNT(*) FROM /eacm/agent_type INTO @DATA(lv_count). "#EC CI_NOWHERE
    IF lv_count > 0.
      out->write( |/EACM/AGENT_TYPE already has { lv_count } entries - skipping.| ).
      RETURN.
    ENDIF.

    lt_types = VALUE #(
      ( agent_type_id = 'MONO' description = 'Monomandatario'  is_active = abap_true )
      ( agent_type_id = 'PLUR' description = 'Plurimandatario' is_active = abap_true )
      ( agent_type_id = 'SUBT' description = 'Sub-agente'      is_active = abap_true )
      ( agent_type_id = 'INAC' description = 'Tipo dismesso'   is_active = abap_false ) ).

    INSERT /eacm/agent_type FROM TABLE @lt_types.

    out->write( |Inserted { lines( lt_types ) } records into /EACM/AGENT_TYPE.| ).
  ENDMETHOD.


  METHOD fill_agents.
    DATA lt_agents TYPE STANDARD TABLE OF /eacm/agent.

    SELECT COUNT(*) FROM /eacm/agent INTO @DATA(lv_count). "#EC CI_NOWHERE
    IF lv_count > 0.
      out->write( |/EACM/AGENT already has { lv_count } entries - skipping.| ).
      RETURN.
    ENDIF.

    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    lt_agents = VALUE #(
      ( agent_id       = 'AG00000001'
        company_code   = '1000'
        agent_name     = 'Rossi Marco - Agente'
        first_name     = 'Marco'
        last_name      = 'Rossi'
        agent_type     = 'MONO'
        company_type   = ''
        company_name   = ''
        vendor_number  = '0000100001'
        customer_number = ''
        vat_number     = 'IT01234567890'
        tax_number     = 'RSSMRC70A01F205X'
        tax_status     = ''
        currency       = 'EUR'
        sales_org      = '1000'
        sales_office   = '1001'
        sales_group    = '100'
        email          = 'marco.rossi@example.com'
        enasarco_exempt = ''
        sub_agent      = ''
        firr_signature  = 'X'
        enasarco_signature = 'X'
        monthly_flag   = ''
        prefix_code    = ''
        description_code = ''
        division_code  = ''
        plant          = '1000'
        valid_from     = lv_today
        valid_to       = '99991231'
        status         = 'A'
        created_by     = lv_user  created_at  = lv_timestamp
        changed_by     = lv_user  changed_at  = lv_timestamp
        local_last_changed_at = lv_timestamp )
      ( agent_id       = 'AG00000002'
        company_code   = '1000'
        agent_name     = 'Bianchi & Partners S.r.l.'
        first_name     = ''
        last_name      = ''
        agent_type     = 'PLUR'
        company_type   = 'SRL'
        company_name   = 'Bianchi & Partners S.r.l.'
        vendor_number  = '0000100002'
        customer_number = ''
        vat_number     = 'IT09876543210'
        tax_number     = '09876543210'
        tax_status     = ''
        currency       = 'EUR'
        sales_org      = '1000'
        sales_office   = '1001'
        sales_group    = '100'
        email          = 'info@bianchipartners.it'
        enasarco_exempt = ''
        sub_agent      = ''
        firr_signature  = 'X'
        enasarco_signature = 'X'
        monthly_flag   = 'X'
        prefix_code    = ''
        description_code = ''
        division_code  = ''
        plant          = '1000'
        valid_from     = lv_today
        valid_to       = '99991231'
        status         = 'A'
        created_by     = lv_user  created_at  = lv_timestamp
        changed_by     = lv_user  changed_at  = lv_timestamp
        local_last_changed_at = lv_timestamp )
      ( agent_id       = 'AG00000003'
        company_code   = '2000'
        agent_name     = 'Verdi Giuseppe - Agente'
        first_name     = 'Giuseppe'
        last_name      = 'Verdi'
        agent_type     = 'MONO'
        company_type   = ''
        company_name   = ''
        vendor_number  = '0000200001'
        customer_number = ''
        vat_number     = 'IT11223344556'
        tax_number     = 'VRDGPP65B15H501Y'
        tax_status     = ''
        currency       = 'EUR'
        sales_org      = '2000'
        sales_office   = '2001'
        sales_group    = '200'
        email          = 'giuseppe.verdi@example.com'
        enasarco_exempt = ''
        sub_agent      = ''
        firr_signature  = 'X'
        enasarco_signature = 'X'
        monthly_flag   = ''
        prefix_code    = ''
        description_code = ''
        division_code  = ''
        plant          = '2000'
        valid_from     = lv_today
        valid_to       = '99991231'
        status         = 'A'
        created_by     = lv_user  created_at  = lv_timestamp
        changed_by     = lv_user  changed_at  = lv_timestamp
        local_last_changed_at = lv_timestamp )
      ( agent_id       = 'AG00000004'
        company_code   = '1000'
        agent_name     = 'Esposito Anna - Sub-agente'
        first_name     = 'Anna'
        last_name      = 'Esposito'
        agent_type     = 'SUBT'
        company_type   = ''
        company_name   = ''
        vendor_number  = '0000100003'
        customer_number = ''
        vat_number     = 'IT55667788990'
        tax_number     = 'SPSNNA80C41F839Z'
        tax_status     = ''
        currency       = 'EUR'
        sales_org      = '1000'
        sales_office   = '1001'
        sales_group    = '100'
        email          = 'anna.esposito@example.com'
        enasarco_exempt = 'X'
        sub_agent      = 'X'
        firr_signature  = ''
        enasarco_signature = ''
        monthly_flag   = ''
        prefix_code    = ''
        description_code = ''
        division_code  = ''
        plant          = '1000'
        valid_from     = lv_today
        valid_to       = '99991231'
        status         = 'S'
        created_by     = lv_user  created_at  = lv_timestamp
        changed_by     = lv_user  changed_at  = lv_timestamp
        local_last_changed_at = lv_timestamp )
      ( agent_id       = 'AG00000005'
        company_code   = '3000'
        agent_name     = 'Neri Paolo - Agente'
        first_name     = 'Paolo'
        last_name      = 'Neri'
        agent_type     = 'MONO'
        company_type   = ''
        company_name   = ''
        vendor_number  = '0000300001'
        customer_number = ''
        vat_number     = 'IT99887766554'
        tax_number     = 'NREPLA60D20L219K'
        tax_status     = ''
        currency       = 'EUR'
        sales_org      = '3000'
        sales_office   = ''
        sales_group    = ''
        email          = ''
        enasarco_exempt = ''
        sub_agent      = ''
        firr_signature  = ''
        enasarco_signature = ''
        monthly_flag   = ''
        prefix_code    = ''
        description_code = ''
        division_code  = ''
        plant          = ''
        valid_from     = '20200101'
        valid_to       = '20241231'
        status         = 'I'
        created_by     = lv_user  created_at  = lv_timestamp
        changed_by     = lv_user  changed_at  = lv_timestamp
        local_last_changed_at = lv_timestamp ) ).

    INSERT /eacm/agent FROM TABLE @lt_agents.

    out->write( |Inserted { lines( lt_agents ) } records into /EACM/AGENT.| ).
  ENDMETHOD.


  METHOD fill_shareholders.
    DATA lt_sh TYPE STANDARD TABLE OF /eacm/agt_shrhld.

    SELECT COUNT(*) FROM /eacm/agt_shrhld INTO @DATA(lv_count). "#EC CI_NOWHERE
    IF lv_count > 0.
      out->write( |/EACM/AGT_SHRHLD already has { lv_count } entries - skipping.| ).
      RETURN.
    ENDIF.

    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    lt_sh = VALUE #(
      ( agent_id         = 'AG00000002'
        shareholder_id   = '0001'
        company_code     = '1000'
        mandate_type     = 'DIR'
        partner_name     = 'Bianchi Luigi'
        participation_pct = '60.00'
        valid_from       = lv_today
        valid_to         = '99991231'
        status           = 'A'
        created_by       = lv_user  created_at = lv_timestamp
        changed_by       = lv_user  changed_at = lv_timestamp )
      ( agent_id         = 'AG00000002'
        shareholder_id   = '0002'
        company_code     = '1000'
        mandate_type     = 'DIR'
        partner_name     = 'Bianchi Maria'
        participation_pct = '40.00'
        valid_from       = lv_today
        valid_to         = '99991231'
        status           = 'A'
        created_by       = lv_user  created_at = lv_timestamp
        changed_by       = lv_user  changed_at = lv_timestamp )
      ( agent_id         = 'AG00000003'
        shareholder_id   = '0001'
        company_code     = '2000'
        mandate_type     = 'DIR'
        partner_name     = 'Verdi Giuseppe'
        participation_pct = '100.00'
        valid_from       = lv_today
        valid_to         = '99991231'
        status           = 'A'
        created_by       = lv_user  created_at = lv_timestamp
        changed_by       = lv_user  changed_at = lv_timestamp ) ).

    INSERT /eacm/agt_shrhld FROM TABLE @lt_sh.

    out->write( |Inserted { lines( lt_sh ) } records into /EACM/AGT_SHRHLD.| ).
  ENDMETHOD.
ENDCLASS.
