-- Owner-assisted password recovery for staff (used until a verified SMS recovery flow is configured).
-- The Owner (MFA-verified) moves an activated staff member back to 'pending_activation'; this cuts all
-- business-data access immediately (current_membership() requires 'active'). The server then issues a
-- fresh one-time code via team_attach_auth_user, and the worker sets a new password on /activate.
begin;

create or replace function public.team_reset_access(p_membership uuid, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_me public.memberships; v_t public.memberships;
begin
  v_me := public.require_permission('team.manage');
  if coalesce(btrim(p_reason), '') = '' then raise exception 'reason required' using errcode = '22023'; end if;
  select * into v_t from public.memberships where id = p_membership and business_id = v_me.business_id for update;
  if v_t.id is null then raise exception 'not found' using errcode = '22023'; end if;
  if v_t.id = v_me.id or v_t.role = 'owner' then
    raise exception 'owner recovery is a separate procedure' using errcode = '42501';
  end if;
  if v_t.status = 'deactivated' then raise exception 'deactivated accounts cannot be reset' using errcode = '22023'; end if;
  update public.memberships set status = (case when v_t.user_id is null then 'invited' else 'pending_activation' end)::public.membership_status
   where id = v_t.id;
  perform public.write_audit(v_me.business_id, 'team.reset_access', 'membership', v_t.id::text,
    jsonb_build_object('status', v_t.status), jsonb_build_object('status', 'pending_activation'), p_reason);
end $$;

revoke all on function public.team_reset_access(uuid, text) from public, anon, authenticated;
grant execute on function public.team_reset_access(uuid, text) to authenticated;

commit;
