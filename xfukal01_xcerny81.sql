drop table PREMIOVYUCET
/

drop table LETENKA
/

drop table UCET
/

drop table LET
/

drop table LETISTE
/

drop table LETECKASPOLECNOST
/

drop sequence Letenka_ID_Sequence
/

drop materialized view pohled_druheho_clena
/

create table Ucet (
    --id Uctu generovano automaticky
    idUctu number generated always as identity primary key,
    jmeno nvarchar2(255) not null,
    prijmeni nvarchar2(255) not null,
    rokNarozeni int not null
);

--Ucet je generalizaci entity PremiovyUcet obsahujici navic atribut sleva, pomoci konstrukce REFERENCES je atribut idUctu propojen
--PremiovyUcet tedy je tedy zavisly na Ucet a atribut sleva lze priradit pouze jiz existujicimu uctu
create table PremiovyUcet (
    idUctu int primary key REFERENCES Ucet(idUctu) ON DELETE CASCADE,
    sleva int not null,
    -- kontrola vstupu slevy
    CONSTRAINT CheckSale CHECK (sleva <= 100 and sleva >= 0)
);

create table Letiste (
    kodLetiste nvarchar2(3) primary key,
    nazev nvarchar2(255) not null,
    mesto nvarchar2(255) not null,
    stat nvarchar2(255) not null,
    -- kontrola vstupu (kod letiste musi mit prave 3 pismena)
    CONSTRAINT CheckCodeLength CHECK (length(kodLetiste) = 3)
);

create table LeteckaSpolecnost (
    ICO int primary key,
    nazev nvarchar2(255) not null,
    zemePusobeni nvarchar2(255) not null,
    reditel nvarchar2(255) not null,
    -- kontrola vstupu (ICO musi mit prave 8 cislic)
    CONSTRAINT CheckICOLength CHECK (length(ICO) = 8)
);

create table Let (
    idLetu int primary key,
    typLetadla nvarchar2(255) not null,
    pocetMist int not null, --POCET VOLNYCH MIST

    ICO int not null,
    kodLetiste_prilet nvarchar2(3) not null,
    kodLetiste_odlet nvarchar2(3) not null,
    CONSTRAINT fk_ICO FOREIGN KEY (ICO) REFERENCES LeteckaSpolecnost(ICO)  ON DELETE CASCADE,
    CONSTRAINT fk_kodLetiste_prilet FOREIGN KEY (kodLetiste_prilet) REFERENCES Letiste(kodLetiste)  ON DELETE CASCADE,
    CONSTRAINT fk_kodLetiste_odlet FOREIGN KEY (kodLetiste_odlet) REFERENCES Letiste(kodLetiste)  ON DELETE CASCADE
);

create table Letenka (
    idLetenky int primary key,
    cena int not null,
    trida nvarchar2(255) not null,
    CONSTRAINT EnumClass CHECK (trida in ('Economy', 'Business', 'First Class')),
    sedadlo int not null,
    jmeno nvarchar2(255),
    prijmeni nvarchar2(255),

    idUctu int,
    idLetu int not null,
    CONSTRAINT fk_idUctu FOREIGN KEY (idUctu) REFERENCES Ucet(idUctu) ON DELETE CASCADE,
    CONSTRAINT fk_idLetu FOREIGN KEY (idLetu) REFERENCES let(idLetu) ON DELETE CASCADE
);


--------------------- TRIGGERY ---------------------
-- tento trigger pri insert do Ucet vzdy zkontroluje ze klient je starsi 18 let
CREATE OR REPLACE TRIGGER kontrolaVeku
BEFORE INSERT ON Ucet
FOR EACH ROW
DECLARE
    vek NUMBER;
BEGIN
    vek := EXTRACT(YEAR FROM SYSDATE) - :NEW.rokNarozeni;
    IF vek < 18 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Osoba musí být starší než 18 let.');
    END IF;
END;
/

-- tento trigger aktualizuje pocet volnych mist na letu - dekrementuje pri pridani letenky na let
CREATE OR REPLACE TRIGGER aktualizacePoctuVolnychMist
AFTER INSERT ON Letenka
FOR EACH ROW
DECLARE
    volnaMista NUMBER;
BEGIN
    -- aktualni pocet volnych mist
    SELECT pocetMist INTO volnaMista
    FROM Let
    WHERE idLetu = :new.idLetu;

    volnaMista := volnaMista - 1;

    -- Kontrola ze pocet volnych mist neklesne pod 0
    IF volnaMista < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cannot add more tickets. No available seats.');
    END IF;

    -- Aktualizace poctu volnych mist
    UPDATE Let
    SET pocetMist = volnaMista
    WHERE idLetu = :new.idLetu;
END;
/

-- Definice sekvence ID letenek
CREATE SEQUENCE Letenka_ID_Sequence
    START WITH 1;

-- Trigger pro prirazeni ID letence podle aktualni hodnoty sekvence ID letenek
CREATE OR REPLACE TRIGGER Letenka_ID_Before_Insert
    BEFORE INSERT ON Letenka
    FOR EACH ROW
BEGIN
    SELECT Letenka_ID_Sequence.NEXTVAL
    INTO :NEW.idLetenky
    FROM DUAL;
END;
/

--------------------- Prodedury ---------------------
/*
 Procedura pro vypsani seznamu odletu pro letiste specifikovano kodem letiste
 Tento kod se vklada do procedury jako parametr
 */
CREATE OR REPLACE PROCEDURE SeznamOdletuLetiste(p_kodLetiste in VARCHAR2)
AS
    CURSOR curLetu IS
        SELECT idLetu, typLetadla, pocetMist
            FROM Let
                WHERE  kodLetiste_odlet = p_kodLetiste;
    BEGIN
        FOR let_rec in curLetu LOOP
            DBMS_OUTPUT.PUT_LINE('ID letu: ' || let_rec.idLetu || ', Typ letadla: ' || let_rec.typLetadla || ', Pocet mist:' || let_rec.pocetMist);
        END loop;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Nebyly nalezeny zadne lety pro zadane letiste.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Chyba'|| SQLERRM);
END;
/

/*
 Procedura pro vypsani seznamu priletu pro letiste specifikovano kodem letiste
 Tento kod se vklada do procedury jako parametr
 */
CREATE OR REPLACE PROCEDURE SeznamPriletuLetiste(p_kodLetiste in VARCHAR2)
AS
    CURSOR curLetu IS
        SELECT idLetu, typLetadla, pocetMist
            FROM Let
                WHERE kodLetiste_prilet = p_kodLetiste;
    BEGIN
        FOR let_rec in curLetu LOOP
            DBMS_OUTPUT.PUT_LINE('ID letu: ' || let_rec.idLetu || ', Typ letadla: ' || let_rec.typLetadla || ', Pocet mist:' || let_rec.pocetMist);
        END loop;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Nebyly nalezeny zadne lety pro zadane letiste.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Chyba'|| SQLERRM);
END;
/

/*
 Tato procedura vyhleda informace o letu na zaklade zadaneho ID letu a vypise je.
 */
CREATE OR REPLACE PROCEDURE VypisInformaceOLetu(p_idLetu in Let.idLetu%TYPE)
AS
    v_typLetadla LeT.typLetadla%TYPE;
    v_pocetMist LeT.pocetMist%TYPE;
    v_priletLetiste LeT.kodLetiste_prilet%TYPE;
    v_odletLetiste LeT.kodLetiste_odlet%TYPE;
BEGIN
    SELECT typLetadla, pocetMist, kodLetiste_prilet, kodLetiste_odlet
    INTO v_typLetadla, v_pocetMist , v_priletLetiste, v_odletLetiste
    FROM LeT
    WHERE idLetu = p_idLetu;

    DBMS_OUTPUT.PUT_LINE('Informace o letu:');
    DBMS_OUTPUT.PUT_LINE('Typ letadla: ' || v_typLetadla);
    DBMS_OUTPUT.PUT_LINE('Pocet mist: ' || v_pocetMist);
    DBMS_OUTPUT.PUT_LINE(v_odletLetiste|| ' --> ' || v_priletLetiste);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Pro zadané ID letu nebyly nalezeny žádné informace.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Chyba'|| SQLERRM);
END;
/


-- testovaci naplneni databaze
INSERT INTO Ucet (jmeno, prijmeni, rokNarozeni) VALUES
('Jan', 'Novák', 1985);

INSERT INTO Ucet (jmeno, prijmeni, rokNarozeni) VALUES
('Bohuslav', 'Pavel', 1970);

INSERT INTO Ucet (jmeno, prijmeni, rokNarozeni) VALUES
('Richard', 'Novotný', 2005);

INSERT INTO Ucet (jmeno, prijmeni, rokNarozeni) VALUES
('Jiří', 'Z Poděbrad', 1999);

INSERT INTO PremiovyUcet (idUctu, sleva) VALUES
(2, 10);

INSERT INTO PremiovyUcet (idUctu, sleva) VALUES
(4, 15);

INSERT INTO Letiste (kodLetiste, nazev, mesto, stat) VALUES
('PRG', 'Letiště Václava Havla Praha', 'Praha', 'Česká republika');

INSERT INTO Letiste (kodLetiste, nazev, mesto, stat) VALUES
('BRQ', 'Letiště Tuřany', 'Brno', 'Česká republika');

INSERT INTO Letiste (kodLetiste, nazev, mesto, stat) VALUES
('LON', 'London Airport', 'London', 'UK');

INSERT INTO Letiste (kodLetiste, nazev, mesto, stat) VALUES
('KTW', 'Katowice Airport', 'Katowice', 'PL');

INSERT INTO Letiste (kodLetiste, nazev, mesto, stat) VALUES
('OSR', 'Ostrava Airport', 'Ostrava', 'CZ');

INSERT INTO LeteckaSpolecnost (ICO, nazev, zemePusobeni, reditel) VALUES
(12345678, 'Czech Airlines', 'Česká republika', 'Petr Nový');

INSERT INTO LeteckaSpolecnost (ICO, nazev, zemePusobeni, reditel) VALUES
(89765432, 'Ryanair', 'Anglie', 'John Black');

INSERT INTO Let (idLetu, typLetadla, pocetMist, ICO, kodLetiste_prilet, kodLetiste_odlet) VALUES
(1, 'Airbus A320', 2, 12345678, 'LON', 'BRQ');

INSERT INTO Let (idLetu, typLetadla, pocetMist, ICO, kodLetiste_prilet, kodLetiste_odlet) VALUES
(2, 'Boeing 737', 220, 89765432, 'PRG', 'LON');

INSERT INTO Let (idLetu, typLetadla, pocetMist, ICO, kodLetiste_prilet, kodLetiste_odlet) VALUES
(3, 'Boeing 737', 220, 89765432, 'KTW', 'OSR');

INSERT INTO Letenka (idLetenky, cena, trida, sedadlo, jmeno, prijmeni, idLetu, idUctu) VALUES
(1, 1000, 'Economy', 1, 'Jakub', 'Horuba', 1, 3);

INSERT INTO Letenka (idLetenky, cena, trida, sedadlo, jmeno, prijmeni, idLetu, idUctu) VALUES
(2, 1200, 'Economy', 115, 'Jan', 'Prkenný', 1, 1);

INSERT INTO Letenka (idLetenky, cena, trida, sedadlo, jmeno, prijmeni, idLetu, idUctu) VALUES
(10, 1200, 'Economy', 154, 'Richard', 'Blue', 2, 4);

INSERT INTO Letenka (idLetenky, cena, trida, sedadlo, jmeno, prijmeni, idLetu, idUctu) VALUES
(4, 899, 'Economy', 199, 'Richard', 'Novotny', 3, 3);
-- konec plneni databaze testovacimy daty


-- volani procedur pro predvedeni funkcionality
CALL SeznamPriletuLetiste('LON');

CALL SeznamOdletuLetiste('LON');

CALL VypisInformaceOLetu(2);

-- Vytvoření indexu na sloupec mesto v tabulce letiste
CREATE INDEX index_mesto ON Letiste(mesto);

-- Dotaz pro ukazku rychleho vyhledavani mesta v tabulce letiste
EXPLAIN PLAN FOR
SELECT *
FROM Letiste
WHERE mesto = 'Praha';
-- Zobrazeni "explain plan" tabulky
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Dotaz 1: Vypisuje jmeno a prijmeni zakaznika, ktery ma premiovy ucet a jeho slevu.
SELECT U.jmeno, U.prijmeni, PU.sleva
FROM Ucet U
JOIN PremiovyUcet PU ON U.idUctu = PU.idUctu;

-- Dotaz 2: Vypisuje ceny vsech letenek koupenych ucty lidi narozenych ve 21. stoleti
SELECT Distinct U.jmeno, U.prijmeni, U.rokNarozeni, L.cena AS cenaLetenky
FROM Letenka L
JOIN Ucet U on L.idUctu = U.idUctu
WHERE U.rokNarozeni > 1999;

-- Dotaz 3: Vypisuje celkovy pocet mist v letech pro kazdou letadlo-spolecnost.
SELECT LS.nazev, L.typLetadla, SUM(L.pocetmist) AS celkovyPocetMist
FROM Let L
JOIN LeteckaSpolecnost LS ON L.ICO = LS.ICO
GROUP BY LS.nazev, L.typLetadla;

-- Dotaz 4: Vypisuje vsechny lety, ktere maji nejake volna mista, které lze zakoupit
SELECT L.*
FROM Let L
WHERE L.pocetMist > 0;

-----------------------------------------------------------------------------------
-- Dotaz 5: Vypisuje vsechny cestujici kteri leti s leteckeckou společností Ryanair
EXPLAIN PLAN FOR
SELECT L.jmeno, L.prijmeni, LE.typLetadla, COUNT(*) AS pocet_letenek
FROM Letenka L
JOIN Let LE ON L.idLetu = LE.idLetu
JOIN LeteckaSpolecnost LS ON LE.ICO = LS.ICO
WHERE LS.nazev = 'Ryanair'
GROUP BY L.jmeno, L.prijmeni, LE.typLetadla;
-- Zobrazeni "explain plan" tabulky
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Vytvoreni indexu na sloupec mestov tabulce LeteckaSpolecnost
CREATE INDEX index_LS ON LeteckaSpolecnost(nazev);

-- Znovu provedeni dotazu po zrychleni pomoci indexu
EXPLAIN PLAN FOR
SELECT L.jmeno, L.prijmeni, LE.typLetadla, COUNT(*) AS pocet_letenek
FROM Letenka L
JOIN Let LE ON L.idLetu = LE.idLetu
JOIN LeteckaSpolecnost LS ON LE.ICO = LS.ICO
WHERE LS.nazev = 'Ryanair'
GROUP BY L.jmeno, L.prijmeni, LE.typLetadla;
-- Zobrazeni "explain plan" tabulky
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
---------------------------------------------------------

-- Dotaz 6: Vypočítá průměrnou cenu letenky pro každou třídu.
SELECT trida, AVG(cena) AS prumer_ceny
FROM Letenka
GROUP BY trida;

-- Dotaz 7: vypisuje vsechny spolecnosti ktere provozuji lety s letadly Boeing (Boeing 737, 747...)
SELECT Distinct LS.nazev
FROM LeteckaSpolecnost LS
JOIN Let L on LS.ICO = L.ICO
Where L.typLetadla IN ('Boeing 737', 'Boeing 737 MAX', 'Boeing 747', 'Boeing 757');

SELECT *
    FROM Letenka;

-- Dotaz 8: Pro dany ucet a letenku vypise cenu letenky a pokud je zakaznik premiovy, tak vypise cenu po sleve.
-- Slouzi pro klasifikaci zakazniku na standardni a premiove.
WITH TypZakaznika AS (
    SELECT
        U.idUctu,
        CASE
            WHEN PU.idUctu IS NOT NULL THEN 'Premiovy'
            ELSE 'Standardni'
            END AS TypZakaznika,
        PU.sleva
    FROM Ucet U
             LEFT JOIN PremiovyUcet PU ON U.idUctu = PU.idUctu
)
-- Vypisuje cenu letenky a pokud je zakaznik premiovy, tak vypise cenu po slevě
SELECT
    L.idLetenky,
    L.cena,
    L.trida,
    TZ.TypZakaznika,
    CASE
        WHEN TZ.TypZakaznika = 'Premiovy' THEN L.cena * (100 - TZ.sleva) / 100
        ELSE L.cena
        END AS CenaPoSleve
FROM Letenka L
         JOIN TypZakaznika TZ ON L.idUctu = TZ.idUctu;

-- pridani druheho clena tymu
-- CREATE ROLE druhy_clen;

-- Pridani prav druhemu clenovi tymu
GRANT SELECT ON Let TO XCERNY81;
GRANT SELECT ON Letenka TO XCERNY81;

-- Vytvoreni m. pohledu pro druheho clena
CREATE MATERIALIZED VIEW pohled_druheho_clena
BUILD IMMEDIATE
REFRESH COMPLETE
AS
SELECT L.*
FROM Let L
WHERE L.pocetMist > 0;

-- Pridani prav druhemu clenovi tymu k jeho materializovanemu pohledu
GRANT SELECT ON pohled_druheho_clena TO XCERNY81;

-- Pouziti pohledu
SELECT * FROM pohled_druheho_clena;
