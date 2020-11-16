-- Query 1
WITH
query_norm(cdscod,cds,year,num) AS (
    SELECT a.cdscod, cds, substr(dtappello, -4) AS year, count(*) AS num
    FROM appelli AS a JOIN iscrizioni AS i ON a.appcod=i.appcod JOIN cds AS c ON c.cdscod=a.cdscod
    GROUP BY a.cdscod, year
),
query_denorm(cdscod,cds,year,num) AS (
    SELECT cdscod, cds, substr(dtappello, -2) AS year, count(*) AS num
    FROM bos_denormalizzato
    GROUP BY cdscod, year
)

SELECT query_norm.cds, query_norm.year, query_norm.num, query_denorm.num AS num_denorm
FROM query_norm JOIN query_denorm ON query_norm.cdscod=query_denorm.cdscod AND
                                     substr(query_norm.year,-2)=query_denorm.year;


-- VIEW per Query 2
CREATE VIEW iscr_sup_ratio_norm as
SELECT isc.cdscod, cds.cds, isc.year, isc.adcod, ad, num_iscritti, IFNULL(num_sup, 0) as num_sup,
       (IFNULL(num_sup,0)*100.0/num_iscritti) as ratio
FROM ((( SELECT appelli.adcod, cdscod, substr(appelli.dtappello, -4) as year, count(*) as num_iscritti
        FROM appelli join iscrizioni on appelli.appcod=iscrizioni.appcod
        GROUP BY appelli.adcod, year, cdscod) as isc LEFT JOIN (SELECT appelli.adcod, cdscod, substr(appelli.dtappello, -4) as year, IFNULL(count(*), 4) as num_sup
        FROM appelli join iscrizioni on appelli.appcod=iscrizioni.appcod
        WHERE iscrizioni.Superamento = 1
        GROUP BY appelli.adcod, year, cdscod) as sup on sup.adcod=isc.adcod AND sup.year=isc.year AND sup.cdscod=isc.cdscod) as esami
    JOIN ad on esami.adcod=ad.adcod JOIN cds on esami.cdscod=cds.cdscod) AS res

-- query 2
select *
from iscr_sup_ratio_norm AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM iscr_sup_ratio_norm AS b
    where b.cdscod=a.cdscod
    ORDER BY b.cdscod, b.year, b.ratio ASC
    LIMIT 10
    )
order by a.cdscod, a.year, a.ratio ASC

-- query 31select res.CdS, sum_commit, sum_tutti, sum_commit*1.0/sum_tutti as tasso_commit
from (select *
from(select c.cdscod, cds, dtappello, sum(count) as sum_commit
      from (select cds.cdscod, cds, dtappello, count(distinct ad) as count
            from (cds join appelli on cds.cdscod=appelli.cdscod) join ad on
                appelli.adcod=ad.adcod
            group by dtappello, cds) as c
      where count>1
      group by c.cds) as commited join

    (select c2.cdscod, cds, dtappello, sum(count) as sum_tutti
      from (select cds.cdscod, cds, dtappello, count(distinct ad) as count
            from (cds join appelli on cds.cdscod=appelli.cdscod) join ad on appelli.adcod=ad.adcod
            group by dtappello, cds) as c2
        group by c2.cds) as tutti
    on tutti.CdS=commited.CdS) as res
order by tasso_commit desc
limit 10

-- query 4
create view media_voto_norm as
SELECT a.cdscod, cds, a.adcod, ad, avg(Voto)
FROM iscrizioni join appelli a on iscrizioni.appcod = a.appcod join
    cds on a.cdscod = cds.cdscod join
    ad on a.adcod = ad.adcod
where Superamento = 1 and Voto is not null
group by a.cdscod, CdS, a.adcod, AD

-- migliori 3
SELECT *
FROM media_voto_norm AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_voto_norm AS b
    where b.cdscod=a.cdscod and b."avg(Voto)" is not null
    ORDER BY b.cdscod, b."avg(Voto)" DESC
    LIMIT 3
    )
order by a.cdscod, a."avg(Voto)" DESC

-- peggiori 3
SELECT *
FROM media_voto_norm AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_voto_norm AS b
    where b.cdscod=a.cdscod and b."avg(Voto)" is not null
    ORDER BY b.cdscod, b."avg(Voto)"
    LIMIT 3
    )
order by a.cdscod, a."avg(Voto)"