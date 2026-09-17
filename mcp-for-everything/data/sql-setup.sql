-- Demo 2 database. Run once against any SQL Server (Express, LocalDB, a VM, Azure SQL)
-- as an admin. Creates the Inventory database, two tables, twelve rows, and a
-- read-only login for the tool to use.
--
--   sqlcmd -S localhost\SQLEXPRESS -E -i data\sql-setup.sql
--   Invoke-Sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -InputFile .\data\sql-setup.sql
--
-- Change the password before you run it. On LocalDB or if you use Integrated
-- Security, skip the login block at the bottom.

IF DB_ID('Inventory') IS NULL CREATE DATABASE Inventory;
GO
USE Inventory;
GO

IF OBJECT_ID('dbo.Inventory') IS NOT NULL DROP TABLE dbo.Inventory;
IF OBJECT_ID('dbo.Products')  IS NOT NULL DROP TABLE dbo.Products;
GO

CREATE TABLE dbo.Products (
    ProductId  INT           NOT NULL PRIMARY KEY,
    Name       NVARCHAR(100) NOT NULL,
    Category   NVARCHAR(50)  NOT NULL,
    UnitPrice  DECIMAL(10,2) NOT NULL
);

CREATE TABLE dbo.Inventory (
    ProductId      INT NOT NULL PRIMARY KEY REFERENCES dbo.Products(ProductId),
    QuantityOnHand INT NOT NULL,
    ReorderPoint   INT NOT NULL
);
GO

INSERT dbo.Products (ProductId, Name, Category, UnitPrice) VALUES
 (1,  'Widget A',            'Widgets',   9.99),
 (2,  'Gadget B',            'Gadgets',   24.99),
 (3,  'Sprocket C',          'Sprockets', 4.25),
 (4,  'Widget Deluxe',       'Widgets',   19.99),
 (5,  'Gadget Pro',          'Gadgets',   89.00),
 (6,  'Sprocket Heavy Duty', 'Sprockets', 12.50),
 (7,  'Widget Mini',         'Widgets',   3.49),
 (8,  'Gadget Lite',         'Gadgets',   14.99),
 (9,  'Sprocket Titanium',   'Sprockets', 48.00),
 (10, 'Widget Industrial',   'Widgets',   129.00),
 (11, 'Gadget Wireless',     'Gadgets',   59.99),
 (12, 'Sprocket Nano',       'Sprockets', 1.15);

INSERT dbo.Inventory (ProductId, QuantityOnHand, ReorderPoint) VALUES
 (1,  12,  50),
 (2,  140, 40),
 (3,  800, 500),
 (4,  8,   25),
 (5,  3,   10),
 (6,  60,  75),
 (7,  1500, 1000),
 (8,  22,  20),
 (9,  2,   5),
 (10, 4,   2),
 (11, 0,   15),
 (12, 9000, 5000);
GO

-- Read-only login. This is the one the tool connects as, and the point of the demo:
-- even if the model somehow got SQL into the query, this login cannot write.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'mcp_reader')
    CREATE LOGIN mcp_reader WITH PASSWORD = 'CHANGE-ME-before-running-1!';
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'mcp_reader')
    CREATE USER mcp_reader FOR LOGIN mcp_reader;
ALTER ROLE db_datareader ADD MEMBER mcp_reader;
GO
