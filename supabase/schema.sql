create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  role text not null default 'student'
    check (role in ('student', 'staff', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('lost', 'found')),
  title text not null check (char_length(title) between 1 and 100),
  description text not null check (char_length(description) between 1 and 2000),
  category text not null check (category in (
    'Phone', 'ID Card', 'Keys', 'Bottle', 'Bag', 'Books', 'Clothing', 'Other'
  )),
  location text not null check (char_length(location) between 1 and 300),
  date timestamptz not null,
  image_path text,
  status text not null default 'open'
    check (status in ('open', 'claimed', 'returned', 'archived')),
  posted_by uuid not null references public.profiles (id) on delete cascade,
  held_at text check (held_at is null or char_length(held_at) <= 300),
  created_at timestamptz not null default now()
);

create table if not exists public.claims (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (id) on delete cascade,
  claimant_id uuid not null references public.profiles (id) on delete cascade,
  verification_answer text not null
    check (char_length(verification_answer) between 1 and 1000),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  unique (item_id, claimant_id)
);

create index if not exists items_feed_idx
  on public.items (type, status, created_at desc);
create index if not exists items_owner_idx
  on public.items (posted_by, created_at desc);
create index if not exists claims_owner_idx
  on public.claims (claimant_id, created_at desc);
create index if not exists claims_item_idx
  on public.claims (item_id, created_at desc);

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null or new.email !~* '@thenyeripoly\.ac\.ke$' then
    raise exception 'Use a school email address';
  end if;

  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    )
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create or replace function public.has_claim_for_item(target_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.claims
    where item_id = target_item_id
      and claimant_id = (select auth.uid())
  );
$$;

alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.claims enable row level security;

drop policy if exists "profiles are visible to their owner and admins"
  on public.profiles;
create policy "profiles are visible to their owner and admins"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "users can update their own profile name"
  on public.profiles;
create policy "users can update their own profile name"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists "admins can update profiles"
  on public.profiles;
create policy "admins can update profiles"
  on public.profiles for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create or replace function public.prevent_non_admin_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role
    and (select auth.uid()) is not null
    and not (select public.is_admin()) then
    raise exception 'Only admins can change profile roles';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role
  before update on public.profiles
  for each row execute function public.prevent_non_admin_role_change();

drop policy if exists "signed-in users can read available and related items"
  on public.items;
create policy "signed-in users can read available and related items"
  on public.items for select to authenticated
  using (
    status = 'open'
    or posted_by = (select auth.uid())
    or (select public.is_admin())
    or (select public.has_claim_for_item(id))
  );

drop policy if exists "users can create their own items"
  on public.items;
create policy "users can create their own items"
  on public.items for insert to authenticated
  with check (
    posted_by = (select auth.uid())
    and status = 'open'
    and (
      image_path is null
      or image_path like (select auth.uid()::text) || '/%'
    )
  );

drop policy if exists "owners and admins can update items"
  on public.items;
create policy "owners and admins can update items"
  on public.items for update to authenticated
  using (
    posted_by = (select auth.uid())
    or (select public.is_admin())
  )
  with check (
    (
      posted_by = (select auth.uid())
      and (
        image_path is null
        or image_path like (select auth.uid()::text) || '/%'
      )
    )
    or (select public.is_admin())
  );

drop policy if exists "owners and admins can delete items"
  on public.items;
create policy "owners and admins can delete items"
  on public.items for delete to authenticated
  using (
    posted_by = (select auth.uid())
    or (select public.is_admin())
  );

drop policy if exists "claimants, item owners, and admins can read claims"
  on public.claims;
create policy "claimants, item owners, and admins can read claims"
  on public.claims for select to authenticated
  using (
    claimant_id = (select auth.uid())
    or exists (
      select 1 from public.items
      where id = item_id and posted_by = (select auth.uid())
    )
    or (select public.is_admin())
  );

drop policy if exists "users can claim another user's open item"
  on public.claims;
create policy "users can claim another user's open item"
  on public.claims for insert to authenticated
  with check (
    claimant_id = (select auth.uid())
    and status = 'pending'
    and exists (
      select 1 from public.items
      where id = item_id
        and status = 'open'
        and posted_by <> (select auth.uid())
    )
  );

drop policy if exists "claimants can edit their own pending answer"
  on public.claims;
create policy "claimants can edit their own pending answer"
  on public.claims for update to authenticated
  using (
    claimant_id = (select auth.uid())
    and status = 'pending'
  )
  with check (
    claimant_id = (select auth.uid())
    and status = 'pending'
  );

drop policy if exists "claimants can delete their own pending claims"
  on public.claims;
create policy "claimants can delete their own pending claims"
  on public.claims for delete to authenticated
  using (
    claimant_id = (select auth.uid())
    and status = 'pending'
  );

grant select, delete on public.items to authenticated;
grant insert (type, title, description, category, location, date, image_path, status, posted_by, held_at)
  on public.items to authenticated;
grant update (type, title, description, category, location, date, image_path, status, held_at)
  on public.items to authenticated;
grant select on public.claims to authenticated;
grant insert (item_id, claimant_id, verification_answer)
  on public.claims to authenticated;
grant update (verification_answer) on public.claims to authenticated;
grant delete on public.claims to authenticated;
grant select on public.profiles to authenticated;
grant update (name, role) on public.profiles to authenticated;

create or replace function public.review_claim(
  p_claim_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_item_id uuid;
  selected_status text;
  item_owner_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if p_approve is null then
    raise exception 'A review decision is required';
  end if;

  select c.item_id, c.status, i.posted_by
  into selected_item_id, selected_status, item_owner_id
  from public.claims as c
  join public.items as i on i.id = c.item_id
  where c.id = p_claim_id
  for update of c, i;

  if not found then
    raise exception 'Claim or item not found';
  end if;
  if item_owner_id <> (select auth.uid())
    and not (select public.is_admin()) then
    raise exception 'Only the item owner or an admin can review this claim';
  end if;
  if selected_status <> 'pending' then
    raise exception 'This claim has already been reviewed';
  end if;
  if p_approve then
    update public.items
    set status = 'claimed'
    where id = selected_item_id and status = 'open';
    if not found then
      raise exception 'This item is no longer open';
    end if;
  end if;

  update public.claims
  set status = case when p_approve then 'approved' else 'rejected' end
  where id = p_claim_id;
end;
$$;

revoke all on function public.review_claim(uuid, boolean) from public;
grant execute on function public.review_claim(uuid, boolean) to authenticated;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'item-photos',
  'item-photos',
  true,
  307200,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "item photos are publicly readable" on storage.objects;
create policy "item photos are publicly readable"
  on storage.objects for select to public
  using (bucket_id = 'item-photos');

drop policy if exists "signed-in users can upload their item photos"
  on storage.objects;
create policy "signed-in users can upload their item photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "owners and admins can update item photos"
  on storage.objects;
create policy "owners and admins can update item photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'item-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid()::text)
      or (select public.is_admin())
    )
  )
  with check (
    bucket_id = 'item-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid()::text)
      or (select public.is_admin())
    )
  );

drop policy if exists "owners and admins can delete item photos"
  on storage.objects;
create policy "owners and admins can delete item photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'item-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid()::text)
      or (select public.is_admin())
    )
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'items'
  ) then
    alter publication supabase_realtime add table public.items;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'claims'
  ) then
    alter publication supabase_realtime add table public.claims;
  end if;
end;
$$;
