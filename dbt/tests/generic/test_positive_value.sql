{% test positive_value(model, column_name) %}
{#
    Custom Generic Test: Positive Value Validation
    Purpose: Validates that a numeric column contains only positive values (greater than 0).
    
    Usage in schema.yml:
        columns:
          - name: order_quantity
            tests:
              - positive_value
    
    Returns: Rows where the column value is <= 0 or null
#}

select
    {{ column_name }} as invalid_value,
    count(*) as occurrences
from {{ model }}
where {{ column_name }} <= 0
    or {{ column_name }} is null
group by {{ column_name }}

{% endtest %}
