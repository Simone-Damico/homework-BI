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