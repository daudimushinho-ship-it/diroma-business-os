-- ---------------------------------------------------------------- report
\pset tuples_only off
\pset format aligned
select n, case when ok then 'PASS' else 'FAIL' end as result, name,
       case when ok then '' else coalesce(detail, '') end as detail
from test.results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed from test.results;
select case when exists (select 1 from test.results where not ok) then 1 else 0 end as failures \gset
\if :failures
  \echo 'DB TESTS FAILED'
  \quit 3
\endif
\echo 'ALL DB TESTS PASSED'
