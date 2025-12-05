{% test revenue_equals_quantity_times_price(model, revenue_col, quantity_col, price_col, discount_col, tolerance=0.01) %}
{#
    Custom Generic Test: Revenue Consistency (Business Logic)
    Purpose: Validates that line_total approximately equals order_quantity * unit_price * (1 - discount).
    
    Usage in schema.yml:
        models:
          - name: slvr_sales_orders
            tests:
              - revenue_equals_quantity_times_price:
                  revenue_col: line_total
                  quantity_col: order_quantity
                  price_col: unit_price
                  discount_col: unit_price_discount
                  tolerance: 0.01
    
    Parameters:
        - revenue_col: Column containing actual revenue/line total
        - quantity_col: Column containing order quantity
        - price_col: Column containing unit price
        - discount_col: Column containing discount (as decimal, e.g., 0.10 for 10%)
        - tolerance: Acceptable difference threshold (default 0.01)
    
    Returns: Rows where calculated revenue differs from actual by more than tolerance
#}

select
    {{ revenue_col }} as actual_revenue,
    {{ quantity_col }} * {{ price_col }} * (1 - COALESCE({{ discount_col }}, 0)) as expected_revenue,
    abs({{ revenue_col }} - ({{ quantity_col }} * {{ price_col }} * (1 - COALESCE({{ discount_col }}, 0)))) as difference
from {{ model }}
where abs({{ revenue_col }} - ({{ quantity_col }} * {{ price_col }} * (1 - COALESCE({{ discount_col }}, 0)))) > {{ tolerance }}

{% endtest %}
