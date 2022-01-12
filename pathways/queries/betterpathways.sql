--Authors: Jordan Strasser, David Lambert (SQL Help)
-- new goal, find when you get to a molecular hub and list it but dont search from it, trying to match with organism
-- issues: getting stuck in self-referential loops. is there a way to log enzyme history?
-- do an enzyme list, in addition to a compound list, and don't allow redundancy, unless you've hit a cycle
with trace as (
select r.accession as accession, 
case
when 'RHEA:'||cast(r.id as text) IN (SELECT reaction from uniprot_to_reaction) then 'RHEA:'||cast(r.id as text)
when 'RHEA:'||cast(r.id-1 as text) IN (SELECT reaction from uniprot_to_reaction) then 'RHEA:'||cast(r.id-1 as text)
when 'RHEA:'||cast(r.id-2 as text) IN (SELECT reaction from uniprot_to_reaction) then 'RHEA:'||cast(r.id-2 as text)
when 'RHEA:'||cast(r.id-3 as text) IN (SELECT reaction from uniprot_to_reaction) then 'RHEA:'||cast(r.id-3 as text)
end as seed
from reaction r
), 
stitch AS (
	select ur.uniprot, a.id as rxn_id,
		b.reactionsidereactiontype,
		d.id as cmpd_id,
		d.name,
		d.formula
		FROM reaction a
		inner join trace t on a.accession  = t.accession
		left join uniprot_to_reaction ur on ur.reaction = t.seed
		inner join reactionsidereaction b on a.accession = b.reaction
		inner join reactionparticipant c USING(reactionside)
		inner join compound d ON c.compound = d.accession
		where b.reactionsidereactiontype <> 'substrateorproduct'
		and d.id != 0
		),
		not_one(ids) AS (
			SELECT cmpd_id FROM (
			SELECT count(*) as count, cmpd_id
		FROM stitch
		GROUP BY cmpd_id
		ORDER BY count(*) DESC )
		WHERE count > 100 -- modify to filter out commonly available molecules
		),
		chain AS (
		select c.uniprot, c.rxn_id, c.cmpd_id as prod_id, c.name as product, c.formula as prod_formula,
		d.name as substrate, d.formula as sub_formula, 0 as lvl,
			c.name|| ',' ||d.name as name_path,
			cast(c.rxn_id as text) as id_path,
			c.uniprot||','||d.uniprot  as uniprot_path,
			CASE
			when d.cmpd_id IN (SELECT ids FROM not_one) then d.cmpd_id-(d.cmpd_id+1)
			else d.cmpd_id
			end as sub_id
			from stitch c
			inner join stitch d on c.rxn_id = d.rxn_id
			where c.cmpd_id = 10019
			and d.reactionsidereactiontype = 'substrate'
			and c.reactionsidereactiontype <> 'substrate'
			UNION ALL
			select e.uniprot, e.rxn_id, e.cmpd_id as prod_id, e.name as product, e.formula as prod_formula,
				f.name as substrate,  f.formula as sub_formula, chain.lvl + 1 as lvl,
				chain.name_path || ',' || f.name as name_path,
				chain.id_path || ',' || cast(e.rxn_id as text) as id_path,
				chain.uniprot_path||','||e.uniprot as uniprot_path,
				CASE
				when f.cmpd_id IN (SELECT ids FROM not_one) then f.cmpd_id-(f.cmpd_id+1)
				else f.cmpd_id
				end as sub_id
				from
				stitch e
				inner join stitch f on e.rxn_id = f.rxn_id
				inner join chain on e.cmpd_id = chain.sub_id
				where lvl < 2
				and f.reactionsidereactiontype LIKE '%substrate%'
				and e.reactionsidereactiontype NOT LIKE '%substrate%'
				and instr(chain.name_path, f.name) = 0
				and instr(chain.id_path, cast(f.rxn_id+1 as text)) = 0 
				and instr(chain.id_path, cast(f.rxn_id-1 as text)) = 0
				)
				select * from chain