-- query 1 --> line chart
SELECT cdscod, cds, "20"||substr(dtappello, -2) AS year,
       CASE
          when DtAppello like '__/__/%'
              then date('20'||substr(dtappello,-2)||'-'||substr(dtappello, 4,2)||'-'||substr(dtappello,1,2))
          end data, count(*) AS num
FROM bos_denormalizzato
GROUP BY year, DtAppello, cdscod, cds
order by data asc


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

-- query 5
CREATE TEMPORARY TABLE median AS
SELECT count(*) as c FROM bos_denormalizzato group by Studente
order by c;

select *
from (SELECT cast(((min(rowid)+max(rowid))/2) as int) as midrow
FROM median) as t, median
where median.ROWID = t.midrow

-- mediana = 7

-- studenti considerati
select *
from bos_denormalizzato
where Studente in (select median.Studente
                    from median
                    where c>=(select c
                            from (SELECT cast(((min(rowid)+max(rowid))/2) as int) as midrow
                            FROM median) as t, median
                            where median.ROWID = t.midrow))

-- finale
drop table median
CREATE TEMPORARY TABLE median AS
SELECT Studente, count(*) as c FROM bos_denormalizzato group by Studente
order by c;

drop table fast_furious;
create temporary table fast_furious as
-- studenti considerati
select stu.CdSCod, stu.CdS, stu.Studente, avg_voto as avg_voto, median.c as num_esami, max(stu.date_norm) as max, min(stu.date_norm) as min,
             julianday(max(stu.date_norm)) - julianday(min(date_norm)) as diff_day
      from (select *,
          CASE
              when DtAppello like '__/__/%'
                  then date('20'||substr(dtappello,-2)||'-'||substr(dtappello, 4,2)||'-'||substr(dtappello,1,2))
              end "date_norm"
      from selected_stu as ss left join bos_denormalizzato as d on d.CdS = ss.CdS and
                                                     d.CdSCod=ss.CdSCod and
                                                     d.Studente=ss.Studente) as stu left join (
                                      select CdSCod, CdS, Studente, avg(Voto) as avg_voto
                                      from bos_denormalizzato
                                      where Voto is not null
                                      group by Studente, CdSCod, CdS
          ) as avg_media_tab on stu.Studente=avg_media_tab.Studente left join median on stu.Studente=median.Studente and
                                                                                        stu.CdSCod=median.CdSCod and
                                                                                        stu.CdS=median.CdS

      group by stu.Studente, stu.CdSCod, stu.CdS;

-- query 5
select *, 0.5*r.avg_voto_norm+0.5*(1-r.diff_day_norm) as ratio
from (select *, (diff_day/(select max(diff_day) from fast_furious)) as diff_day_norm,
             (avg_voto/(select max(avg_voto) from fast_furious)) as avg_voto_norm
from fast_furious) as r
order by ratio desc

-- quety 6
select a.adcod, a.AD, a.cds, avg(a.tent) as tentativi
from (select AdCod, CdS, ad, count(*) -1 as tent
    from bos_denormalizzato
    group by Studente, ad, AdCod, CdS) as a
group by a.adcod, a.AD
order by tentativi DESC
limit 3

-- query 7: media voti a seconda della residenza
select a.CdS, a.StuResArea, avg(a.tent) as tentativi
from (select CdS, StuResArea, count(*) -1 as tent
    from bos_denormalizzato
    group by Studente, StuResArea, CdS, AD) as a
group by a.CdS, a.StuResArea
order by tentativi DESC

-- query 7: crediti di merito
-- view media 27
CREATE VIEW media_27 as
select v27.CdSCod, v27.CdS, count(v27.voto27) as media_27
                from
             (select CdSCod, cds, avg(Voto) as voto27
                  from bos_denormalizzato
                  group by Studente, CdS, CdSCod
                  having voto27 >= 27
                     and voto27 < 28) as v27
            group by v27.CdS, v27.CdSCod;

-- view media 28
CREATE VIEW media_28 as
select v28.CdSCod, v28.CdS, count(v28.voto28) as media_28
                from
                (select CdSCod, cds, avg(Voto) as voto28
                 from bos_denormalizzato
                 group by Studente, CdS
                 having voto28 >= 28
                    and voto28 < 29)  as v28
                group by v28.CdS, v28.CdSCod;

-- view mwedia 29-30
CREATE VIEW media_2930 as
select v2930.CdSCod, v2930.CdS, count(v2930.voto2930) as media_2930
            from
            (select CdSCod, cds, avg(Voto) as voto2930
             from bos_denormalizzato
             group by Studente, CdS
             having voto2930 >= 29)  as v2930
            group by v2930.CdS, v2930.CdSCod;

--  view per la prime unione
CREATE VIEW media2728_1 as
select *
from media_27 left join media_28 on media_27.CdSCod=media_28.CdSCod
union all
select *
from media_28 left join media_27 on media_27.CdSCod=media_28.CdSCod
where media_27.CdSCod is null;

-- query
select res.CdSCod, res.cds, res.media_27, res.media_28, res.media_2930,
       res.media_27*125+res.media_28*250+res.media_2930*500 as cred_merito
from (select *
from media2728_1 join media_2930 on media2728_1.CdSCod=media_2930.CdSCod
union
select *
from media2728_1 join media_2930 on media2728_1.CdSCod=media_2930.CdSCod
where media2728_1.CdSCod is null) as res
order by cred_merito desc
