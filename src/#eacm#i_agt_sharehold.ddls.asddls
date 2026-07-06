@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'eACM - Agent Shareholder (Interface)'
define view entity /EACM/I_AGT_SHAREHOLD
  as select from /eacm/agt_shrhld
  association to parent /EACM/I_AGENT as _Agent on $projection.AgentID = _Agent.AgentID
{
      @EndUserText.label: 'Agent ID'
  key agent_id            as AgentID,

      @EndUserText.label: 'Shareholder ID'
  key shareholder_id      as ShareholderID,

      @EndUserText.label: 'Company Code'
      company_code        as CompanyCode,

      @EndUserText.label: 'Mandate Type'
      mandate_type        as MandateType,

      @EndUserText.label: 'Partner Name'
      partner_name        as PartnerName,

      @EndUserText.label: 'Participation %'
      participation_pct   as ParticipationPct,

      @EndUserText.label: 'Valid From'
      valid_from          as ValidFrom,

      @EndUserText.label: 'Valid To'
      valid_to            as ValidTo,

      @EndUserText.label: 'Status'
      status              as Status,

      /* Calculated: Status Criticality */
      case status
        when 'A' then 3
        when 'I' then 1
        else 0
      end                 as StatusCriticality,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by          as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at          as CreatedAt,

      @EndUserText.label: 'Changed By'
      @Semantics.user.lastChangedBy: true
      changed_by          as ChangedBy,

      @EndUserText.label: 'Changed At'
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at          as ChangedAt,

      /* Association */
      _Agent
}
