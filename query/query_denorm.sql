-- View query 2
create view iscr_sup_ratio as
      select res.cdscod, res.CdS, res.year, res.adcod, res.ad, res.num_iscr, IFNULL(res.passati, 0) as passati,
             IFNULL(res.passati, 0)*100.0/res.num_iscr as ratio
      from (SELECT bos_denormalizzato.adcod, bos_denormalizzato.CdS, bos_denormalizzato.ad, substr(dtappello, -2) as year,
          bos_denormalizzato.cdscod, count(*) as num_iscr, passati.num_sup as passati
          FROM bos_denormalizzato left join (SELECT adcod, CdScod, substr(dtappello, -2) as year, IFNULL(count(*), 0) as num_sup
                                      FROM bos_denormalizzato
                                      WHERE Superamento = 1
                                      GROUP BY adcod, substr(dtappello, -2), CdScod) as passati
              on bos_denormalizzato.adcod=passati.adcod and
                 substr(bos_denormalizzato.dtappello, -2) = passati.year and
                 bos_denormalizzato.CdSCod=passati.CdSCod
      GROUP BY bos_denormalizzato.adcod, substr(dtappello, -2), bos_denormalizzato.cdscod, bos_denormalizzato.ad)
          as res

-- query 2
SELECT *
FROM iscr_sup_ratio AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM iscr_sup_ratio AS b
    where b.cdscod=a.cdscod
    ORDER BY b.cdscod, b.year, b.ratio ASC
    LIMIT 10
    )
order by a.cdscod, a.year, a.ratio ASC

-- query 3
select res.CdS, sum_commit, sum_tutti, sum_commit*1.0/sum_tutti as tasso_commit
from ((select *, sum(commited.count_tutti) as sum_tutti
     from (SELECT CdS, DtAppello, count(distinct ad) as count_tutti
            FROM bos_denormalizzato
            group by DtAppello, CdS) as commited
    group by commited.CdS) as tutti join

    (select *, sum(commited.count_commit) as sum_commit
     from (SELECT CdS, DtAppello, count(distinct ad) as count_commit
            FROM bos_denormalizzato
            group by DtAppello, CdS) as commited
    where commited.count_commit > 1
    group by commited.CdS) as commited on
        tutti.CdS=commited.CdS and tutti.DtAppello=commited.DtAppello) as res
group by res.CdS
order by tasso_commit DESC
limit 10

-- query 4
create view media_esami as
select CdSCod, CdS, AdCod, AD, avg(Voto) as voto_medio
from bos_denormalizzato
where Superamento = 1
group by CdSCod, CdS, AdCod, AD

-- peggiori 3
SELECT *
FROM media_esami AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_esami AS b
    where b.cdscod=a.cdscod and b.voto_medio is not null
    ORDER BY b.cdscod, b.voto_medio ASC
    LIMIT 3
    )
order by a.cdscod, a.voto_medio ASC

-- migliori 3
SELECT *
FROM media_esami AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_esami AS b
    where b.cdscod=a.cdscod and b.voto_medio is not null
    ORDER BY b.cdscod, b.voto_medio DESC
    LIMIT 3
    )
order by a.cdscod, a.voto_medio DESC