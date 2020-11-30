-- Query 1
.header on
.mode csv
.output "csv/query1.csv"
SELECT a.cdscod, cds, substr(dtappello, -4) AS year,
       CASE
           when dtappello like '__/_/%'
               then date(substr(dtappello,-4)||'-0'||substr(dtappello, 4,1)||'-'||substr(dtappello,1,2))
           when dtappello like '_/_/%'
               then date(substr(dtappello,-4)||'-0'||substr(dtappello, 3,1)||'-0'||substr(dtappello,1,1))
           when dtappello like '_/__/%'
               then date(substr(dtappello,-4)||'-'||substr(dtappello, 3,2)||'-0'||substr(dtappello,1,1))
           when dtappello like '__/__/%'
               then date(substr(dtappello,-4)||'-'||substr(dtappello, 4,2)||'-'||substr(dtappello,1,2))
       END data, count(*) AS num
FROM appelli AS a JOIN iscrizioni AS i ON a.appcod=i.appcod JOIN cds AS c ON c.cdscod=a.cdscod
GROUP BY a.cdscod, year, DtAppello, cds
ORDER BY data;

-- query 2
.header on
.mode csv
.output "csv/query2.csv"
DROP TABLE IF EXISTS iscr_sup_ratio_norm;
CREATE TEMPORARY TABLE iscr_sup_ratio_norm AS
    SELECT res.cdscod AS cdscod, res.cds AS cds, res.year AS year, res.adcod AS adcod, ad,
           num_iscritti, IFNULL(num_sup, 0) AS num_sup, (IFNULL(num_sup,0)*100.0/num_iscritti) AS ratio
    FROM (
        select *
        from (select * from (
        SELECT appelli.adcod, cdscod, substr(appelli.dtappello, -4) AS year, count(*) AS num_iscritti
        FROM appelli JOIN iscrizioni ON appelli.appcod=iscrizioni.appcod
        GROUP BY appelli.adcod, year, cdscod) AS isc
        LEFT JOIN (
        SELECT appelli.adcod, cdscod, substr(appelli.dtappello, -4) AS year, IFNULL(count(*), 4) AS num_sup
        FROM appelli JOIN iscrizioni ON appelli.appcod=iscrizioni.appcod
        WHERE iscrizioni.Superamento = 1
        GROUP BY appelli.adcod, year, cdscod) AS sup ON sup.adcod=isc.adcod AND
                                                        sup.year=isc.year AND sup.cdscod=isc.cdscod) AS esami
    JOIN ad on esami.adcod=ad.adcod JOIN cds ON esami.cdscod=cds.cdscod) AS res;

-- query finale
SELECT *
FROM iscr_sup_ratio_norm AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM iscr_sup_ratio_norm AS b
    WHERE b.cdscod=a.cdscod
    ORDER BY b.cdscod, b.year, b.ratio
    LIMIT 10
    )
ORDER BY a.cdscod, a.year, a.ratio;


-- query 3
.header on
.mode csv
.output "csv/query3.csv"
SELECT res.CdS AS cds, sum_commit, sum_tutti, sum_commit*1.0/sum_tutti AS tasso_commit
FROM (
    SELECT *
    FROM (
        SELECT cdscod, cds, sum(count) AS sum_tutti
        FROM (
            SELECT cds.cdscod, cds, count(DISTINCT ad) AS count
            FROM (cds JOIN appelli ON cds.cdscod=appelli.cdscod) JOIN ad ON appelli.adcod=ad.adcod
            GROUP BY dtappello, cds)
        GROUP BY cds) AS tutti
        LEFT JOIN (
                SELECT c.cdscod, cds, sum(count) AS sum_commit
        FROM (
            SELECT cds.cdscod, cds, count(DISTINCT ad) AS count
            FROM (cds JOIN appelli ON cds.cdscod=appelli.cdscod) JOIN ad ON appelli.adcod=ad.adcod
            GROUP BY dtappello, cds) AS c
        WHERE count>1
        GROUP BY c.cds) AS commited ON tutti.CdS=commited.CdS) AS res
ORDER BY tasso_commit DESC;


-- query 4
DROP TABLE IF EXISTS media_voto_norm;
CREATE TEMPORARY TABLE media_voto_norm AS
    SELECT a.cdscod AS cdscod, cds, a.adcod AS adcod, ad, avg(Voto) AS voto
    FROM iscrizioni JOIN appelli a ON iscrizioni.appcod = a.appcod JOIN cds ON a.cdscod = cds.cdscod
        JOIN ad ON a.adcod = ad.adcod
    WHERE Superamento = 1 AND Voto IS NOT NULL
    GROUP BY a.cdscod, CdS, a.adcod, AD;

.header on
.mode csv
.output "csv/query4_migliori.csv"
-- migliori 3
SELECT *
FROM media_voto_norm AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_voto_norm AS b
    WHERE b.cdscod=a.cdscod AND b.voto IS NOT NULL
    ORDER BY b.cdscod, b.voto DESC
    LIMIT 3
    )
ORDER BY a.cdscod, a.voto DESC;

.header on
.mode csv
.output "csv/query4_peggiori.csv"
-- peggiori 3
SELECT *
FROM media_voto_norm AS a
WHERE a.adcod IN (
    SELECT b.adcod
    FROM media_voto_norm AS b
    WHERE b.cdscod=a.cdscod AND b.voto IS NOT NULL
    ORDER BY b.cdscod, b.voto
    LIMIT 3
    )
ORDER BY a.cdscod, a.voto;



.header on
.mode csv
.output "csv/query5.csv"
-- query 5
DROP TABLE IF EXISTS median;
CREATE TEMPORARY TABLE median AS
SELECT cds.CdS, cds.CdSCod, Studente, count(*) AS count
FROM iscrizioni JOIN appelli ON iscrizioni.appcod=appelli.appcod JOIN cds
                ON appelli.cdscod = cds.cdscod
GROUP BY Studente, cds.CdS, cds.CdSCod
ORDER BY count;

DROP TABLE IF EXISTS fast_furious_norm;
CREATE TEMPORARY TABLE fast_furious_norm AS
    SELECT stu.cdscod AS cdscod, stu.cds AS cds, stu.Studente studente, IFNULL(avg_voto,0) AS avg_voto, median.count AS num_esami,
           max(stu.date_norm) AS max, min(stu.date_norm) AS min,
           julianday(max(stu.date_norm)) - julianday(min(stu.date_norm)) AS diff_day
    FROM (
        SELECT *,
               CASE
                   WHEN dtappello LIKE '__/_/%'
                       THEN date(substr(dtappello,-4)||'-0'||substr(dtappello, 4,1)||'-'||substr(dtappello,1,2))
                   WHEN dtappello LIKE '_/_/%'
                       THEN date(substr(dtappello,-4)||'-0'||substr(dtappello, 3,1)||'-0'||substr(dtappello,1,1))
                   WHEN dtappello LIKE '_/__/%'
                       THEN date(substr(dtappello,-4)||'-'||substr(dtappello, 3,2)||'-0'||substr(dtappello,1,1))
                   WHEN dtappello LIKE '__/__/%'
                       THEN date(substr(dtappello,-4)||'-'||substr(dtappello, 4,2)||'-'||substr(dtappello,1,2))
               END "date_norm"
        FROM (
            SELECT *
            FROM median
            WHERE count>= (
                SELECT count
                FROM (
                    SELECT cast(((min(rowid)+max(rowid))/2) AS INTEGER) AS midrow
                    FROM median) AS t, median
                WHERE median.ROWID = t.midrow)) AS select_stud
        LEFT JOIN (
            iscrizioni JOIN appelli ON iscrizioni.appcod=appelli.appcod JOIN cds c
                ON appelli.cdscod = c.cdscod) AS all_stu ON all_stu.CdS = select_stud.CdS AND
                                                            all_stu.CdSCod=select_stud.cdscod AND
                                                            all_stu.Studente=select_stud.Studente) AS stu
    LEFT JOIN (
        SELECT cds, appelli.cdscod, studente, avg(Voto) AS avg_voto
        FROM iscrizioni JOIN appelli ON iscrizioni.appcod=appelli.appcod JOIN ad ON appelli.adcod=ad.adcod
            JOIN cds AS c ON appelli.cdscod = c.cdscod
        WHERE Voto IS NOT NULL
        GROUP BY Studente, cds, appelli.cdscod) AS avg_media_tab ON stu.Studente=avg_media_tab.Studente
        LEFT JOIN median ON stu.Studente=median.Studente AND stu.cds=median.CdS AND stu.CdSCod=median.CdSCod


    GROUP BY stu.Studente, stu.cdscod, stu.cds;

-- query finale per l'indicatore
SELECT *, studente, 0.5*r.avg_voto_norm+0.5*((1-r.diff_day_norm)*(num_esami_norm)) AS ratio
FROM (
    SELECT *, (diff_day/(SELECT max(diff_day) FROM fast_furious_norm)) AS diff_day_norm,
             (avg_voto/(SELECT max(avg_voto) FROM fast_furious_norm)) AS avg_voto_norm,
             (1.0*num_esami/(select max(num_esami) from fast_furious_norm)) AS num_esami_norm
FROM fast_furious_norm) AS r
ORDER BY ratio DESC;


-- query 6
.header on
.mode csv
.output "csv/query6.csv"
SELECT a.adcod, a.AD, a.cds, avg(a.tent) AS tentativi
FROM (
    SELECT ad.AdCod, CdS, ad, count(*) AS tent
    FROM iscrizioni JOIN appelli ON iscrizioni.appcod=appelli.appcod JOIN ad ON appelli.adcod=ad.adcod
        JOIN cds AS c ON appelli.cdscod = c.cdscod
            WHERE Superamento = 0
    GROUP BY Studente, ad, ad.AdCod, CdS) AS a
GROUP BY a.adcod, a.AD
ORDER BY tentativi DESC
LIMIT 3;


-- query 7
-- calcolo medie
.header on
.mode csv
.output "csv/query7.csv"
DROP TABLE IF EXISTS media_27_norm;
CREATE TEMPORARY TABLE media_27_norm AS
    SELECT v27.CdSCod AS cdscod, v27.CdS AS cds, count(v27.voto27) AS media_v27
    FROM (
        SELECT appelli.CdSCod, cds, avg(Voto) AS voto27
        FROM appelli JOIN cds c ON appelli.cdscod = c.cdscod JOIN iscrizioni i ON appelli.appcod = i.appcod
        GROUP BY Studente, CdS, appelli.CdSCod
        HAVING voto27 >= 27 and voto27 < 28) AS v27
    GROUP BY v27.CdS, v27.CdSCod;

DROP TABLE IF EXISTS media_28_norm;
CREATE TEMPORARY TABLE media_28_norm AS
    SELECT v28.CdSCod AS cdscod, v28.CdS AS cds, count(v28.voto28) AS media_v28
    FROM (
        SELECT appelli.CdSCod, cds, avg(Voto) AS voto28
        FROM appelli JOIN cds AS c ON appelli.cdscod = c.cdscod JOIN iscrizioni AS i ON appelli.appcod = i.appcod
        GROUP BY Studente, CdS, appelli.CdSCod
        HAVING voto28 >= 28 and voto28 < 29) AS v28
    GROUP BY v28.CdS, v28.CdSCod;

DROP TABLE IF EXISTS media_2930_norm;
CREATE TEMPORARY TABLE media_2930_norm AS
    SELECT v2930.CdSCod AS cdscod, v2930.CdS AS cds, count(v2930.voto2930) AS media_v2930
    FROM (
        SELECT appelli.CdSCod, cds, avg(Voto) AS voto2930
        FROM appelli JOIN cds AS c ON appelli.cdscod = c.cdscod JOIN iscrizioni AS i ON appelli.appcod = i.appcod
        GROUP BY Studente, CdS, appelli.CdSCod
        HAVING voto2930 >= 29) AS v2930
    GROUP BY v2930.CdS, v2930.CdSCod;

-- unione delle medie
DROP TABLE IF EXISTS media2728_norm;
CREATE TEMPORARY TABLE media2728_norm AS
    SELECT *
    FROM media_27_norm LEFT JOIN media_28_norm ON media_27_norm.CdSCod=media_28_norm.CdSCod
    UNION ALL
    SELECT *
    FROM media_28_norm LEFT JOIN media_27_norm ON media_27_norm.CdSCod=media_28_norm.CdSCod
    WHERE media_27_norm.CdSCod IS NULL;

-- query finale
SELECT res.CdSCod AS cdsCod, res.cds AS cds, res.media_v27 AS media_27, res.media_v28 AS media_28, res.media_v2930 AS media_2930,
       res.media_V27*125+res.media_v28*250+res.media_v2930*500 AS cred_merito
FROM (
    SELECT *
    FROM media2728_norm JOIN media_2930_norm ON media2728_norm.CdSCod=media_2930_norm.CdSCod
    UNION ALL
    SELECT *
    FROM media2728_norm JOIN media_2930_norm ON media2728_norm.CdSCod=media_2930_norm.CdSCod
    WHERE media2728_norm.CdSCod IS NULL ) AS res
ORDER BY cred_merito desc;