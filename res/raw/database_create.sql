CREATE TABLE IF NOT EXISTS ACCOUNTLIST_V1(
ACCOUNTID integer primary key,
ACCOUNTNAME TEXT NOT NULL,
ACCOUNTTYPE TEXT NOT NULL,
ACCOUNTNUM TEXT,
STATUS TEXT NOT NULL, 
NOTES TEXT,
HELDAT TEXT,
WEBSITE TEXT,
CONTACTINFO TEXT,
ACCESSINFO TEXT,
INITIALBAL numeric,
FAVORITEACCT TEXT NOT NULL,
CURRENCYID integer NOT NULL);

CREATE TABLE IF NOT EXISTS ASSETS_V1(ASSETID integer primary key,
STARTDATE TEXT NOT NULL,
ASSETNAME TEXT,
VALUE numeric,
VALUECHANGE TEXT,
NOTES TEXT,
VALUECHANGERATE numeric,
ASSETTYPE TEXT);

CREATE TABLE IF NOT EXISTS BILLSDEPOSITS_V1(BDID integer primary key,
ACCOUNTID integer NOT NULL,
TOACCOUNTID integer,
PAYEEID integer NOT NULL,
TRANSCODE TEXT NOT NULL,
TRANSAMOUNT numeric NOT NULL,
STATUS TEXT,
TRANSACTIONNUMBER TEXT,
NOTES TEXT,
CATEGID integer,
SUBCATEGID integer,
TRANSDATE TEXT,
FOLLOWUPID integer,
TOTRANSAMOUNT numeric,
REPEATS numeric,
NEXTOCCURRENCEDATE TEXT,
NUMOCCURRENCES numeric);

CREATE TABLE IF NOT EXISTS BUDGETSPLITTRANSACTIONS_V1(
SPLITTRANSID integer primary key,
TRANSID integer NOT NULL,
CATEGID integer,
SUBCATEGID integer,
SPLITTRANSAMOUNT numeric);

CREATE TABLE IF NOT EXISTS BUDGETTABLE_V1(
BUDGETENTRYID integer primary key,
BUDGETYEARID integer,
CATEGID integer,
SUBCATEGID integer,
PERIOD TEXT NOT NULL,
AMOUNT numeric NOT NULL);

CREATE TABLE IF NOT EXISTS BUDGETYEAR_V1(
BUDGETYEARID integer primary key,
BUDGETYEARNAME TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS CATEGORY_V1(
CATEGID integer primary key,
CATEGNAME TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS CHECKINGACCOUNT_V1(
TRANSID integer primary key,
ACCOUNTID integer NOT NULL,
TOACCOUNTID integer,
PAYEEID integer NOT NULL,
TRANSCODE TEXT NOT NULL,
TRANSAMOUNT numeric NOT NULL,
STATUS TEXT,
TRANSACTIONNUMBER TEXT,
NOTES TEXT,
CATEGID integer,
SUBCATEGID integer,
TRANSDATE TEXT,
FOLLOWUPID integer,
TOTRANSAMOUNT numeric);

CREATE TABLE IF NOT EXISTS CURRENCYFORMATS_V1(
CURRENCYID integer primary key,
CURRENCYNAME TEXT NOT NULL,
PFX_SYMBOL TEXT,
SFX_SYMBOL TEXT,
DECIMAL_POINT TEXT,
GROUP_SEPARATOR TEXT,
UNIT_NAME TEXT,
CENT_NAME TEXT,
SCALE numeric,
BASECONVRATE numeric,
CURRENCY_SYMBOL TEXT);

CREATE TABLE IF NOT EXISTS INFOTABLE_V1 (
INFOID integer not null primary key,
INFONAME TEXT NOT NULL,
INFOVALUE TEXT NOT NULL );

CREATE TABLE IF NOT EXISTS PAYEE_V1(
PAYEEID integer primary key,
PAYEENAME TEXT NOT NULL,
CATEGID integer,
SUBCATEGID integer);

CREATE TABLE IF NOT EXISTS SPLITTRANSACTIONS_V1(
SPLITTRANSID integer primary key,
TRANSID numeric NOT NULL,
CATEGID integer,
SUBCATEGID integer,
SPLITTRANSAMOUNT numeric);

CREATE TABLE IF NOT EXISTS STOCK_V1(
STOCKID integer primary key,
HELDAT numeric,
PURCHASEDATE TEXT NOT NULL,
STOCKNAME TEXT,
SYMBOL TEXT,
NUMSHARES numeric,
PURCHASEPRICE numeric NOT NULL,
NOTES TEXT,
CURRENTPRICE numeric NOT NULL,
VALUE numeric,
COMMISSION numeric);

CREATE TABLE IF NOT EXISTS SUBCATEGORY_V1(
SUBCATEGID integer primary key,
SUBCATEGNAME TEXT NOT NULL,
CATEGID integer NOT NULL);

DROP VIEW IF EXISTS alldata;

CREATE VIEW IF NOT EXISTS alldata AS
       SELECT CANS.TransID AS ID,
              CANS.TransCode AS TransactionType,
              date( CANS.TransDate, 'localtime' ) AS Date,
              d.userdate AS UserDate,
              coalesce( CAT.CategName, SCAT.CategName ) AS Category,
              coalesce( SUBCAT.SUBCategName, SSCAT.SUBCategName, '' ) AS Subcategory,
              ROUND( ( CASE CANS.TRANSCODE 
                       WHEN 'Withdrawal' THEN -1 
                       ELSE 1 
              END ) *  ( CASE CANS.CATEGID 
                       WHEN -1 THEN st.splittransamount 
                       ELSE CANS.TRANSAMOUNT 
              END ) , 2 ) AS Amount,
              cf.currency_symbol AS currency,
              CANS.Status AS Status,
              CANS.NOTES AS Notes,
              cf.BaseConvRate AS BaseConvRate,
              FROMACC.CurrencyID AS CurrencyID,
              FROMACC.AccountName AS AccountName,
              FROMACC.AccountID AS AccountID,
              ifnull( TOACC.AccountName, '' ) AS ToAccountName,
              ifnull( TOACC.ACCOUNTId, -1 ) AS ToAccountID,
              CANS.ToTransAmount ToTransAmount,
              ifnull( TOACC.CURRENCYID, -1 ) AS ToCurrencyID,
              ( CASE ifnull( CANS.CATEGID, -1 ) 
                       WHEN -1 THEN 1 
                       ELSE 0 
              END ) AS Splitted,
              ifnull( CAT.CategId, st.CategId ) AS CategID,
              ifnull( ifnull( SUBCAT.SubCategID, st.subCategId ) , -1 ) AS SubCategID,
              ifnull( PAYEE.PayeeName, '' ) AS Payee,
              ifnull( PAYEE.PayeeID, -1 ) AS PayeeID,
              CANS.TRANSACTIONNUMBER AS TransactionNumber,
              d.year AS Year,
              d.month AS Month,
              d.day AS Day,
              d.finyear AS FinYear
         FROM CHECKINGACCOUNT_V1 CANS
              LEFT JOIN CATEGORY_V1 CAT
                     ON CAT.CATEGID = CANS.CATEGID
              LEFT JOIN SUBCATEGORY_V1 SUBCAT
                     ON SUBCAT.SUBCATEGID = CANS.SUBCATEGID 
       AND
       SUBCAT.CATEGID = CANS.CATEGID
              LEFT JOIN PAYEE_V1 PAYEE
                     ON PAYEE.PAYEEID = CANS.PAYEEID
              LEFT JOIN ACCOUNTLIST_V1 FROMACC
                     ON FROMACC.ACCOUNTID = CANS.ACCOUNTID
              LEFT JOIN ACCOUNTLIST_V1 TOACC
                     ON TOACC.ACCOUNTID = CANS.TOACCOUNTID
              LEFT JOIN splittransactions_v1 st
                     ON CANS.transid = st.transid
              LEFT JOIN CATEGORY_V1 SCAT
                     ON SCAT.CATEGID = st.CATEGID 
       AND
       CANS.TransId = st.transid
              LEFT JOIN SUBCATEGORY_V1 SSCAT
                     ON SSCAT.SUBCATEGID = st.SUBCATEGID 
       AND
       SSCAT.CATEGID = st.CATEGID 
       AND
       CANS.TransId = st.transid
              LEFT JOIN currencyformats_v1 cf
                     ON cf.currencyid = FROMACC.currencyid
              LEFT JOIN  ( 
           SELECT transid AS id,
                  date( transdate, 'localtime' ) AS transdate,
                  round( strftime( '%d', transdate, 'localtime' )  ) AS day,
                  round( strftime( '%m', transdate, 'localtime' )  ) AS month,
                  round( strftime( '%Y', transdate, 'localtime' )  ) AS year,
                  round( strftime( '%Y', transdate, 'localtime', 'start of month',  (  ( CASE
                               WHEN fd.infovalue <= round( strftime( '%d', transdate, 'localtime' )  ) THEN 1 
                               ELSE 0 
                  END ) - fm.infovalue ) || ' month' )  ) AS finyear,
                  ifnull( ifnull( strftime( df.infovalue, TransDate, 'localtime' ) ,  ( strftime( REPLACE( df.infovalue, '%y', SubStr( strftime( '%Y', TransDate, 'localtime' ) , 3, 2 )  ) , TransDate, 'localtime' )  )  ) , date( TransDate, 'localtime' )  ) AS UserDate
             FROM CHECKINGACCOUNT_V1
                  LEFT JOIN infotable_v1 df
                         ON df.infoname = 'DATEFORMAT'
                  LEFT JOIN infotable_v1 fm
                         ON fm.infoname = 'FINANCIAL_YEAR_START_MONTH'
                  LEFT JOIN infotable_v1 fd
                         ON fd.infoname = 'FINANCIAL_YEAR_START_DAY' 
       ) 
       d
                     ON d.id = CANS.TRANSID
        ORDER BY CANS.transid;
		
CREATE TABLE IF NOT EXISTS "android_metadata" ("locale" TEXT DEFAULT 'en_US');

-- INSERT INTO ALL CURRENCIES
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Albania Lek', 'ALL', 'Lek', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Argentina Peso', 'ARS', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Aruba Guilder', 'AWG', 'ƒ', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Australia Dollar', 'AUD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Azerbaijan New Manat', 'AZN', 'ман', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Bahamas Dollar', 'BSD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Barbados Dollar', 'BBD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Belarus Ruble', 'BYR', 'p.', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Belize Dollar', 'BZD', 'BZ$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Bermuda Dollar', 'BMD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Bolivia Boliviano', 'BOB', '$b', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Bosnia and Herzegovina Convertible Marka', 'BAM', 'KM', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Botswana Pula', 'BWP', 'P', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Bulgaria Lev', 'BGN', 'лв', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Brazil Real', 'BRL', 'R$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Brunei Darussalam Dollar', 'BND', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Cambodia Riel', 'KHR', '៛', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Canada Dollar', 'CAD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Cayman Islands Dollar', 'KYD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Chile Peso', 'CLP', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('China Yuan Renminbi', 'CNY', '¥', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Colombia Peso', 'COP', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Costa Rica Colon', 'CRC', '₡', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Croatia Kuna', 'HRK', 'kn', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Cuba Peso', 'CUP', '₱', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Czech Republic Koruna', 'CZK', 'Kč', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Denmark Krone', 'DKK', 'kr', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Dominican Republic Peso', 'DOP', 'RD$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('East Caribbean Dollar', 'XCD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Egypt Pound', 'EGP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('El Salvador Colon', 'SVC', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Estonia Kroon', 'EEK', 'kr', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Euro Member Countries', 'EUR', '€', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Falkland Islands (Malvinas) Pound', 'FKP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Fiji Dollar', 'FJD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Ghana Cedis', 'GHC', '¢', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Gibraltar Pound', 'GIP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Guatemala Quetzal', 'GTQ', 'Q', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Guernsey Pound', 'GGP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Guyana Dollar', 'GYD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Honduras Lempira', 'HNL', 'L', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Hong Kong Dollar', 'HKD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Hungary Forint', 'HUF', 'Ft', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Iceland Krona', 'ISK', 'kr', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('India Rupee', 'INR', '', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Indonesia Rupiah', 'IDR', 'Rp', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Iran Rial', 'IRR', '﷼', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Isle of Man Pound', 'IMP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Israel Shekel', 'ILS', '₪', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Jamaica Dollar', 'JMD', 'J$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Japan Yen', 'JPY', '¥', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Jersey Pound', 'JEP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Kazakhstan Tenge', 'KZT', 'лв', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Korea (North) Won', 'KPW', '₩', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Korea (South) Won', 'KRW', '₩', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Kyrgyzstan Som', 'KGS', 'лв', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Laos Kip', 'LAK', '₭', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Latvia Lat', 'LVL', 'Ls', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Lebanon Pound', 'LBP', '£', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Liberia Dollar', 'LRD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Lithuania Litas', 'LTL', 'Lt', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Macedonia Denar', 'MKD', 'ден', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Malaysia Ringgit', 'MYR', 'RM', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Mauritius Rupee', 'MUR', '₨', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Mexico Peso', 'MXN', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Mongolia Tughrik', 'MNT', '₮', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Mozambique Metical', 'MZN', 'MT', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Namibia Dollar', 'NAD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Nepal Rupee', 'NPR', '₨', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Netherlands Antilles Guilder', 'ANG', 'ƒ', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('New Zealand Dollar', 'NZD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Nicaragua Cordoba', 'NIO', 'C$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Nigeria Naira', 'NGN', '₦', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Korea (North) Won', 'KPW', '₩', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Norway Krone', 'NOK', 'kr', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Oman Rial', 'OMR', '﷼', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Pakistan Rupee', 'PKR', '₨', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Panama Balboa', 'PAB', 'B/.', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Paraguay Guarani', 'PYG', 'Gs', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Peru Nuevo Sol', 'PEN', 'S/.', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Philippines Peso', 'PHP', '₱', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Poland Zloty', 'PLN', 'zł', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Qatar Riyal', 'QAR', '﷼', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Romania New Leu', 'RON', 'lei', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Russia Ruble', 'RUB', 'руб', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Saint Helena Pound', 'SHP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Saudi Arabia Riyal', 'SAR', '﷼', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Serbia Dinar', 'RSD', 'Дин', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Seychelles Rupee', 'SCR', '₨', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Singapore Dollar', 'SGD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Solomon Islands Dollar', 'SBD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Somalia Shilling', 'SOS', 'S', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('South Africa Rand', 'ZAR', 'R', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Korea (South) Won', 'KRW', '₩', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Sri Lanka Rupee', 'LKR', '₨', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Sweden Krona', 'SEK', 'kr', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Switzerland Franc', 'CHF', 'CHF', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Suriname Dollar', 'SRD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Syria Pound', 'SYP', '£', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Taiwan New Dollar', 'TWD', 'NT$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Thailand Baht', 'THB', '฿', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Trinidad and Tobago Dollar', 'TTD', 'TT$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Turkey Lira', 'TRY', '', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Turkey Lira', 'TRL', '₤', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Tuvalu Dollar', 'TVD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Ukraine Hryvna', 'UAH', '₴', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('United Kingdom Pound', 'GBP', '£', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('United States Dollar', 'USD', '$', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Uruguay Peso', 'UYU', '$U', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Uzbekistan Som', 'UZS', 'лв', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Venezuela Bolivar', 'VEF', 'Bs', '.', ',', 100, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Viet Nam Dong', 'VND', '₫', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Yemen Rial', 'YER', '﷼', '.', ',', 1, 1);
INSERT INTO CURRENCYFORMATS_V1 (CURRENCYNAME, CURRENCY_SYMBOL, PFX_SYMBOL, GROUP_SEPARATOR, DECIMAL_POINT, SCALE, BASECONVRATE)  VALUES ('Zimbabwe Dollar', 'ZWD', 'Z$', '.', ',', 100, 1);

-- INFO USER
INSERT INTO INFOTABLE_V1 VALUES(1,'USERNAME','');