{% test date_not_in_future(model, column_name) %}
{#
    Custom Generic Test: Date Not in Future
    Purpose: Validates that date columns do not contain future dates.
    
    Usage in schema.yml:
        columns:
          - name: order_date
            tests:
              - date_not_in_future
    
    Returns: Rows where the date is in the future
    Note: Uses GETDATE() for SQL Server compatibility
#}

select
    {{ column_name }} as invalid_date,
    count(*) as occurrences
from {{ model }}
where {{ column_name }} > GETDATE()
group by {{ column_name }}

{% endtest %}
