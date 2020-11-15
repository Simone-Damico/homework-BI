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