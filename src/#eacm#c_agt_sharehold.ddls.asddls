@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'eACM - Agent Shareholder (Consumption)'
@Metadata.allowExtensions: true
define view entity /EACM/C_AGT_SHAREHOLD
  as projection on /EACM/I_AGT_SHAREHOLD
{
  key AgentID,
  key ShareholderID,
      CompanyCode,
      MandateType,
      PartnerName,
      ParticipationPct,
      ValidFrom,
      ValidTo,
      Status,
      StatusCriticality,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,

      _Agent : redirected to parent /EACM/C_AGENT
}
