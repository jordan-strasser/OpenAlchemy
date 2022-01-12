--input genbank id of designed organism and formula of compound you wish to check if already present
-- output is name(s) and formula of the compound

WITH native_rxns as (
select distinct case
when r.directional = 0
then r.id + 1
else r.id
end id
from uniprot u 
inner join uniprot_to_reaction ur on u.accession = ur.uniprot 
inner join reaction r on ur.reaction = r.accession
where u.seqhash IN (
select s.translation  
from genbank g inner join genbankfeatures gf 
on g.accession = gf.genbank 
inner join seqhash s on gf.seqhash = s.seqhash 
WHERE g.accession = ? -- organism param
) 
),
-- native_rxns selects from 'case' because uniprot_to_reaction includes the base parent reactions that are undirectional. 
-- sometimes only these parent reaction have an associated enzyme. 
-- modified to r.id + 1 so that it can match items within the stitch cte 
 
 -- formats the allbase tables in a conenient way to see reaction participants, ids, names
 stitch as ( 
 select a.accession, a.id as rxn_id,
		b.reactionside,
		b.reactionsidereactiontype,
		c.compound,
		d.id as cmpd_id,
		d.name as name,
		d.formula as formula
		FROM reaction a
		inner join reactionsidereaction b on a.accession = b.reaction
		inner join reactionparticipant c USING(reactionside)
		inner join compound d ON c.compound = d.accession
		where b.reactionsidereactiontype <> 'substrateorproduct'
        and d.id != 0 
		and rxn_id IN (select id from native_rxns) -- organism filter
		or rxn_id IN (select id+1 from native_rxns) -- gets reverse reactions also
		)

		-- finds most common compounds in an organism to avoid trivial pathways 

		select distinct name, formula
		from stitch 
		where formula = ?