@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'eACM - Agent (Interface)'
define root view entity /EACM/I_AGENT
  as select from /eacm/agent
  composition [0..*] of /EACM/I_AGT_SHAREHOLD as _Shareholder
  association [0..*] to /EACM/I_COMPANY       as _Company      on $projection.CompanyCode = _Company.SapCompanyCode
  association [0..1] to /EACM/I_AGENT_TYPE_VH as _AgentType    on $projection.AgentTypeCode = _AgentType.AgentTypeID
{
      @EndUserText.label: 'Agent ID'
  key agent_id              as AgentID,

      @EndUserText.label: 'Company Code'
      company_code          as CompanyCode,

      @EndUserText.label: 'Agent Name'
      agent_name            as AgentName,

      @EndUserText.label: 'First Name'
      first_name            as FirstName,

      @EndUserText.label: 'Last Name'
      last_name             as LastName,

      @EndUserText.label: 'Agent Type'
      agent_type            as AgentTypeCode,

      @EndUserText.label: 'Company Type'
      company_type          as CompanyType,

      @EndUserText.label: 'Company Name'
      company_name          as CompanyName,

      @EndUserText.label: 'Vendor Number'
      vendor_number         as VendorNumber,

      @EndUserText.label: 'Customer Number'
      customer_number       as CustomerNumber,

      @EndUserText.label: 'VAT Number'
      vat_number            as VatNumber,

      @EndUserText.label: 'Tax Number'
      tax_number            as TaxNumber,

      @EndUserText.label: 'Tax Status'
      tax_status            as TaxStatus,

      @EndUserText.label: 'Currency'
      @Consumption.valueHelpDefinition: [{ entity: {name: 'I_Currency', element: 'Currency' }, useForValidation: true }]
      currency              as Currency,

      @EndUserText.label: 'Sales Organization'
      sales_org             as SalesOrg,

      @EndUserText.label: 'Sales Office'
      sales_office          as SalesOffice,

      @EndUserText.label: 'Sales Group'
      sales_group           as SalesGroup,

      @EndUserText.label: 'Email'
      email                 as Email,

      @EndUserText.label: 'ENASARCO Exempt'
      cast( enasarco_exempt as abap_boolean ) as EnasarcoExempt,

      @EndUserText.label: 'Sub-Agent'
      cast( sub_agent as abap_boolean ) as SubAgent,


      @EndUserText.label: 'FIRR Signature'
      cast( firr_signature as abap_boolean ) as FirrSignature,

      @EndUserText.label: 'ENASARCO Signature'
      cast( enasarco_signature as abap_boolean ) as EnasarcoSignature,

      @EndUserText.label: 'Monthly Flag'
      cast( monthly_flag as abap_boolean ) as MonthlyFlag,

      @EndUserText.label: 'Prefix Code'
      prefix_code           as PrefixCode,

      @EndUserText.label: 'Description Code'
      description_code      as DescriptionCode,

      @EndUserText.label: 'Division Code'
      division_code         as DivisionCode,

      @EndUserText.label: 'Plant'
      plant                 as Plant,

      @EndUserText.label: 'Valid From'
      valid_from            as ValidFrom,

      @EndUserText.label: 'Valid To'
      valid_to              as ValidTo,

      @EndUserText.label: 'Status'
      status                as Status,

      /* Calculated: Status Criticality for UI */
      case status
        when 'A' then 3
        when 'S' then 2
        when 'I' then 1
        else 0
      end                   as StatusCriticality,

      /* Calculated: Agent Type Description */
      _AgentType.Description as AgentTypeText,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @EndUserText.label: 'Changed By'
      @Semantics.user.lastChangedBy: true
      changed_by            as ChangedBy,

      @EndUserText.label: 'Changed At'
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at            as ChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      /* Associations */
      _Shareholder,
      _Company,
      _AgentType
}
