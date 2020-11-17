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

-- query 5
-- normalizzazione date
select adcod, dtappello,
    CASE
        when dtappello like '__/_/%'
            then date(substr(dtappello,-4)||'-0'||substr(dtappello, 4,1)||'-'||substr(dtappello,1,2))
        when dtappello like '_/_/%'
            then date(substr(dtappello,-4)||'-0'||substr(dtappello, 3,1)||'-0'||substr(dtappello,1,1))
        when dtappello like '_/__/%'
            then date(substr(dtappello,-4)||'-'||substr(dtappello, 3,2)||'-0'||substr(dtappello,1,1))
        when dtappello like '__/__/%'
            then date(substr(dtappello,-4)||'-'||substr(dtappello, 1,2)||'-'||substr(dtappello,4,2))
        end "date_norm"
from appelli


-- query 6
select a.adcod, a.AD, a.cds, avg(a.tent) as tentativi
from (select ad.AdCod, CdS, ad, count(*) -1 as tent
from iscrizioni join appelli on iscrizioni.appcod=appelli.appcod
                join ad on appelli.adcod=ad.adcod
                join cds c on appelli.cdscod = c.cdscod
group by Studente, ad, ad.AdCod, CdS) as a
group by a.adcod, a.AD
order by tentativi DESC
limit 3


--query 7

-- views medie
CREATE VIEW media_27_norm as
select v27.CdSCod, v27.CdS, count(v27.voto27) as media_27
                from
             (select appelli.CdSCod, cds, avg(Voto) as voto27
                  from appelli join cds c on appelli.cdscod = c.cdscod join
    iscrizioni i on appelli.appcod = i.appcod
                  group by Studente, CdS, appelli.CdSCod
                  having voto27 >= 27
                     and voto27 < 28) as v27
            group by v27.CdS, v27.CdSCod;

CREATE VIEW media_28_norm as
select v28.CdSCod, v28.CdS, count(v28.voto28) as media_28
                from
             (select appelli.CdSCod, cds, avg(Voto) as voto28
                  from appelli join cds c on appelli.cdscod = c.cdscod join
    iscrizioni i on appelli.appcod = i.appcod
                  group by Studente, CdS, appelli.CdSCod
                  having voto28 >= 28
                     and voto28 < 29) as v28
            group by v28.CdS, v28.CdSCod;

CREATE VIEW media_2930_norm as
select v2930.CdSCod, v2930.CdS, count(v2930.voto2930) as media_2930
                from
             (select appelli.CdSCod, cds, avg(Voto) as voto2930
                  from appelli join cds c on appelli.cdscod = c.cdscod join
    iscrizioni i on appelli.appcod = i.appcod
                  group by Studente, CdS, appelli.CdSCod
                  having voto2930 >= 29) as v2930
            group by v2930.CdS, v2930.CdSCod;

-- view unione
CREATE VIEW media2728_norm as
select *
from media_27_norm left join media_28_norm on media_27_norm.CdSCod=media_28_norm.CdSCod
union all
select *
from media_28_norm left join media_27_norm on media_27_norm.CdSCod=media_28_norm.CdSCod
where media_27_norm.CdSCod is null;


-- query
select res.CdSCod, res.cds, res.media_27, res.media_28, res.media_2930,
       res.media_27*125+res.media_28*250+res.media_2930*500 as cred_merito
from (select *
from media2728_norm join media_2930_norm on media2728_norm.CdSCod=media_2930_norm.CdSCod
union
select *
from media2728_norm join media_2930_norm on media2728_norm.CdSCod=media_2930_norm.CdSCod
where media2728_norm.CdSCod is null) as res
order by cred_merito desc