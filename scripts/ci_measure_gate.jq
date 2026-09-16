# State is selected from recorded evidence, never from observed performance.
def state:
  if $job == "jac-check" then
    if ($context[0].analysis_cache.matched // "") != "" then "restored"
    elif ($attempt | tonumber? // 1) > 1 then "retry-cold"
    else "cold" end
  else "local" end;
def valid_limit:
  type == "object" and
  (.wall_seconds | type == "number" and . > 0 and isfinite) and
  (.max_rss_mib | type == "number" and . > 0 and isfinite);
state as $state |
($budgets[0].jobs[$job] // {}) as $phases |
# Validate all configured states, including ones this run does not exercise.
if all($budgets[0].jobs[][][]; valid_limit) then .
else error("invalid performance budget") end |
. as $measurements |
([.[].phase] + ($phases | keys) | unique) as $names |
[$names[] as $phase |
 ($measurements | map(select(.phase == $phase)) | .[0]) as $measurement |
 ($phases[$phase][$state] // null) as $budget |
 if $measurement == null and $budget == null then empty
 else
   ($measurement // {phase:$phase}) + {
     state:$state, budget:$budget,
     mode:(if $budget == null then "report" else "enforce" end),
     failures:(if $budget == null then []
       elif $measurement == null then ["missing required measurement"]
       else [
         if $measurement.exit_code != 0 then "command failed" else empty end,
         if $measurement.wall_seconds > $budget.wall_seconds then "wall budget exceeded" else empty end,
         if $measurement.max_rss_mib > $budget.max_rss_mib then "memory budget exceeded" else empty end
       ] end)
   }
 end] |
{state:$state, results:., failures:[.[] | select(.failures | length > 0) | {phase, failures}]}
