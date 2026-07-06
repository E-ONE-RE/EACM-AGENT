@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'eACM - Agent (Consumption)'
@Metadata.allowExtensions: true
define root view entity /EACM/C_AGENT
  provider contract transactional_query
  as projection on /EACM/I_AGENT
{
  key AgentID,
      CompanyCode,
      AgentName,
      FirstName,
      LastName,
      AgentTypeCode,
      AgentTypeText,
      CompanyType,
      CompanyName,
      VendorNumber,
      CustomerNumber,
      VatNumber,
      TaxNumber,
      TaxStatus,
      Currency,
      SalesOrg,
      SalesOffice,
      SalesGroup,
      Email,
      EnasarcoExempt,
      SubAgent,
      FirrSignature,
      EnasarcoSignature,
      MonthlyFlag,
      PrefixCode,
      DescriptionCode,
      DivisionCode,
      Plant,
      ValidFrom,
      ValidTo,
      @Consumption.valueHelpDefinition: [{ entity: { name: '/EACM/I_COMPANY_STATUS_VH', element: 'Status' } }]
      Status,
      StatusCriticality,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _Shareholder : redirected to composition child /EACM/C_AGT_SHAREHOLD,
      _Company
      
}

