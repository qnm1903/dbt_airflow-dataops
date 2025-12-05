{% test valid_percentage(model, column_name) %}
{#
    Custom Generic Test: Valid Percentage Range
    Purpose: Validates that percentage values are between 0 and 100.
    
    Usage in schema.yml:
        columns:
          - name: discount_percentage
            tests:
              - valid_percentage
    
    Returns: Rows where the percentage is outside 0-100 range or null
#}

select
    {{ column_name }} as invalid_percentage,
    count(*) as occurrences
from {{ model }}
where {{ column_name }} < 0 
    or {{ column_name }} > 100
    or {{ column_name }} is null
group by {{ column_name }}

{% endtest %}
