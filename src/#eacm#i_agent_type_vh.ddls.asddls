@EndUserText.label: 'eACM - Agent Type Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity /EACM/I_AGENT_TYPE_VH
  as select from /eacm/agent_type
{
      @EndUserText.label: 'Agent Type'
      @ObjectModel.text.element: ['Description']
  key agent_type_id as AgentTypeID,

      @EndUserText.label: 'Description'
      @Semantics.text: true
      description   as Description,

      @EndUserText.label: 'Active'
      is_active     as IsActive
}
where
  is_active = 'X'
