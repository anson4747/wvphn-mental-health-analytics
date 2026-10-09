-- Generic test: the combination of columns is unique. Written in-house to avoid a package dependency.
{% test unique_combination_of_columns(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
