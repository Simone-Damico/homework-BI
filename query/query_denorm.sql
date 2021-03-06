-- query 1
SELECT cdscod, cds, '20'||substr(dtappello, -2) AS year,
       CASE
          when DtAppello like '__/__/%'
              then date('20'||substr(dtappello,-2)||'-'||substr(dtappello, 4,2)||'-'||substr(dtappello,1,2))
          END data, count(*) AS num
FROM bos_denormalizzato
GROUP BY year, DtAppello, cdscod, cds
ORDER BY data;

-- query 2
DROP TABLE IF EXISTS iscr_sup_ratio;
CREATE TEMPORARY TABLE iscr_sup_ratio AS
    SELECT res.cdscod AS cdscod, res.CdS AS cds, res.year AS year, res.adcod AS adcod, res.ad AS ad, res.num_iscr AS num_iscr,
           IFNULL(res.passati, 0) AS passati, IFNULL(res.passati, 0)*100.0/res.num_iscr AS ratio
    FROM (
        SELECT bos_denormalizzato.adcod, bos_denormalizzato.CdS, bos_denormalizzato.ad,
               substr(dtappello, -2) AS year, bos_denormalizzato.cdscod, count(*) AS num_iscr,
               passati.num_sup AS passati
        FROM bos_denormalizzato
        LEFT JOIN (
        SELECT adcod, CdScod, substr(dtappello, -2) AS year, IFNULL(count(*), 0) AS num_sup
        FROM bos_denormalizzato
        WHERE Superamento = 1
        GROUP BY adcod, substr(dtappello, -2), CdScod) AS passati
            ON bos_denormalizzato.adcod=passati.adcod AND
               substr(bos_denormalizzato.dtappello,-2)=passati.year AND
               bos_denormalizzato.CdSCod=passati.CdSCod
    GROUP BY bos_denormalizzato.adcod, substr(dtappello,-2), bos_denormalizzato.cdscod,
             bos_denormalizzato.ad) AS res;

-- query finale
SELECT *
FROM iscr_sup_ratio AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM iscr_sup_ratio AS b
    where b.cdscod=a.cdscod
    ORDER BY b.cdscod, b.year, b.ratio
    LIMIT 10
    )
ORDER BY a.cdscod, a.year, a.ratio;


-- query 3
SELECT res.CdS AS cds, sum_commit, sum_tutti, sum_commit*1.0/sum_tutti AS tasso_commit
FROM (
    SELECT *
    FROM (
        SELECT CdSCod, CdS, sum(count) AS sum_tutti
        FROM (
            SELECT CdSCod, CdS, count(DISTINCT ad) AS count
            FROM bos_denormalizzato
            GROUP BY dtappello, CdS)
        GROUP BY cds) AS tutti
        LEFT JOIN (
        SELECT CdSCod, CdS, sum(count) AS sum_commit
        FROM (
            SELECT CdSCod, CdS, count(DISTINCT ad) AS count
            FROM bos_denormalizzato
            GROUP BY dtappello, CdS) AS c
        WHERE count>1
        GROUP BY c.cds) AS commited ON tutti.CdS=commited.CdS) AS res
ORDER BY tasso_commit DESC;


-- query 4
DROP TABLE IF EXISTS media_esami;
CREATE TEMPORARY TABLE media_esami as
    SELECT CdSCod, CdS, AdCod, AD, avg(Voto) AS voto_medio
    FROM bos_denormalizzato
    WHERE Superamento = 1
    GROUP BY CdSCod, CdS, AdCod, AD;

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
order by a.cdscod, a.voto_medio DESC;

-- peggiori 3
SELECT *
FROM media_esami AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_esami AS b
    WHERE b.cdscod=a.cdscod AND b.voto_medio IS NOT NULL
    ORDER BY b.cdscod, b.voto_medio
    LIMIT 3
    )
ORDER BY a.cdscod, a.voto_medio;

-- query 5
DROP TABLE IF EXISTS median;
CREATE TEMPORARY TABLE median AS
SELECT CdS, CdSCod, Studente, count(*) AS c
FROM bos_denormalizzato
GROUP BY Studente, CdS, CdSCod
ORDER BY c;

DROP TABLE IF EXISTS fast_furious;
CREATE TEMPORARY TABLE fast_furious AS
    SELECT stu.CdSCod AS cdscod, stu.CdS AS cds, stu.Studente AS Studente, avg_voto AS avg_voto, median.c AS num_esami,
           max(stu.date_norm) AS max, min(stu.date_norm) AS min,
           julianday(max(stu.date_norm)) - julianday(min(date_norm)) AS diff_day
    FROM (
        SELECT *,
          CASE
              WHEN DtAppello LIKE '__/__/%'
                  THEN date('20'||substr(dtappello,-2)||'-'||substr(dtappello, 4,2)||'-'||substr(dtappello,1,2))
              END "date_norm"
        FROM (
            SELECT *
            FROM median
            WHERE c>=(
                SELECT c
                FROM (
                    SELECT cast(((min(rowid)+max(rowid))/2) AS INTEGER) AS midrow
                    FROM median) as t, median
                    WHERE median.ROWID = t.midrow)) AS ss
        LEFT JOIN bos_denormalizzato AS d ON d.CdS = ss.CdS AND
                                             d.CdSCod=ss.CdSCod AND
                                             d.Studente=ss.Studente) AS stu
    LEFT JOIN (
        SELECT CdSCod, CdS, Studente, avg(Voto) AS avg_voto
        FROM bos_denormalizzato
        WHERE Voto IS NOT NULL
        GROUP BY Studente, CdSCod, CdS) AS avg_media_tab ON stu.Studente=avg_media_tab.Studente
    LEFT JOIN median ON stu.Studente=median.Studente AND stu.CdSCod=median.CdSCod AND stu.CdS=median.CdS
    GROUP BY stu.Studente, stu.CdSCod, stu.CdS;

-- query finale per l'indicatore
SELECT *, 0.5*r.avg_voto_norm+0.5*((1-r.diff_day_norm)*(num_esami_norm)) AS ratio
FROM (
    SELECT *, (diff_day/(SELECT max(diff_day) FROM fast_furious)) AS diff_day_norm,
             (avg_voto/(SELECT max(avg_voto) FROM fast_furious)) AS avg_voto_norm,
			(1.0*num_esami/(select max(num_esami) from fast_furious)) AS num_esami_norm
FROM fast_furious) AS r
ORDER BY ratio DESC;


-- query 6
SELECT a.adcod, a.AD, a.cds, avg(a.tent) AS tentativi
FROM (
    SELECT AdCod, CdS, ad, count(*) AS tent
    FROM bos_denormalizzato
    WHERE Superamento = 0
    GROUP BY Studente, ad, AdCod, CdS) AS a
GROUP BY a.adcod, a.AD
ORDER BY tentativi DESC
LIMIT 3;


-- query 7: crediti di merito
-- calcolo medie
DROP TABLE IF EXISTS media_27;
CREATE TEMPORARY TABLE media_27 AS
    SELECT v27.CdSCod AS cdscod, v27.CdS AS cds, count(v27.voto27) AS media_27
    FROM (
        SELECT CdSCod, cds, avg(Voto) as voto27
        FROM bos_denormalizzato
        GROUP BY Studente, CdS, CdSCod
        HAVING voto27 >= 27 AND voto27 < 28) AS v27
    GROUP BY v27.CdS, v27.CdSCod;

DROP TABLE IF EXISTS media_28;
CREATE TEMPORARY TABLE media_28 AS
    SELECT v28.CdSCod AS cdscod, v28.CdS AS cds, count(v28.voto28) AS media_28
    FROM (
        SELECT CdSCod, cds, avg(Voto) AS voto28
        FROM bos_denormalizzato
        GROUP BY Studente, CdS
        HAVING voto28 >= 28 AND voto28 < 29) AS v28
    GROUP BY v28.CdS, v28.CdSCod;

DROP TABLE IF EXISTS media_2930;
CREATE TEMPORARY TABLE media_2930 AS
     SELECT v2930.CdSCod AS cdscod, v2930.CdS AS cds, count(v2930.voto2930) AS media_2930
     FROM (
         SELECT CdSCod, cds, avg(Voto) AS voto2930
         FROM bos_denormalizzato
         GROUP BY Studente, CdS
         HAVING voto2930 >= 29) AS v2930
     GROUP BY v2930.CdS, v2930.CdSCod;

--  unione delle medie
DROP TABLE IF EXISTS media2728;
CREATE TEMPORARY TABLE media2728 AS
    SELECT *
    FROM media_27 LEFT JOIN media_28 ON media_27.cdscod=media_28.CdSCod
    UNION ALL
    SELECT *
    FROM media_28 LEFT JOIN media_27 ON media_27.cdscod=media_28.CdSCod
    WHERE media_27.cdscod IS NULL;

-- query finale
SELECT res.CdSCod, res.cds, res.media_27, res.media_28, res.media_2930,
       res.media_27*125+res.media_28*250+res.media_2930*500 AS cred_merito
FROM (
    SELECT *
    FROM media2728 LEFT JOIN media_2930 ON media2728.CdSCod=media_2930.CdSCod
    UNION ALL
    SELECT *
    FROM media2728 LEFT JOIN media_2930 ON media2728.CdSCod=media_2930.CdSCod
    WHERE media2728.CdSCod IS NULL) AS res
ORDER BY cred_merito DESC;
