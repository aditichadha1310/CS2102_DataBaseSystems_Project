DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Departments;
DROP TABLE IF EXISTS Contacts;
DROP TABLE IF EXISTS Meeting_rooms;
DROP TABLE IF EXISTS Junior;
DROP TABLE IF EXISTS Booker;
DROP TABLE IF EXISTS Health_declaration;
DROP TABLE IF EXISTS Senior;
DROP TABLE IF EXISTS Manager;
DROP TABLE IF EXISTS Updates;
DROP TABLE IF EXISTS Sessions;
DROP TABLE IF EXISTS Joins;


CREATE TABLE Departments (
did INTEGER PRIMARY KEY,
dname TEXT
);

CREATE TABLE Employees (
eid INTEGER PRIMARY KEY,
ename VARCHAR(100),
email VARCHAR(100),
resigned_date DATE, 
did INTEGER NOT NULL,
FOREIGN KEY(did) REFERENCES Departments(did) ON UPDATE CASCADE
--CHECK(employees.email LIKE ‘%@%’)
);

CREATE TABLE Contacts (
eid INTEGER,
contact_1 INTEGER NOT NULL,
contact_2 INTEGER,
contact_3 INTEGER,
FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE 
);

CREATE TABLE Junior (
eid INTEGER PRIMARY KEY,
ename VARCHAR(100),
email VARCHAR(100),
resigned_date DATE, 
did INTEGER NOT NULL,
FOREIGN KEY(did) REFERENCES Departments(did) ON UPDATE CASCADE,
FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Booker (
eid INTEGER PRIMARY KEY,
ename VARCHAR(100),
email VARCHAR(100),
resigned_date DATE, 
did INTEGER NOT NULL,
FOREIGN KEY(did) REFERENCES Departments(did) ON UPDATE CASCADE,
FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE Senior (
eid INTEGER PRIMARY KEY,
ename VARCHAR(100),
email VARCHAR(100),
resigned_date DATE, 
did INTEGER NOT NULL,
FOREIGN KEY(did) REFERENCES Departments(did) ON UPDATE CASCADE,
FOREIGN KEY (eid) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Manager (
eid INTEGER PRIMARY KEY,
ename VARCHAR(100),
email VARCHAR(100),
resigned_date DATE, 
did INTEGER NOT NULL,
FOREIGN KEY(did) REFERENCES Departments(did) ON UPDATE CASCADE,
FOREIGN KEY (eid) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Meeting_Rooms (
room INTEGER,
floor INTEGER,
rname TEXT, 
did INTEGER,
PRIMARY KEY (room, floor),
FOREIGN KEY(did) REFERENCES Departments(did) ON UPDATE CASCADE
);

CREATE TABLE Sessions (
time TIME,
date DATE,
room INTEGER,
floor INTEGER,
eid INTEGER,
approver_eid INTEGER,
num_participants INTEGER,
PRIMARY KEY(time, date, room, floor),
FOREIGN KEY (eid) REFERENCES Booker(eid) ON UPDATE CASCADE,
FOREIGN KEY (approver_eid) REFERENCES Manager(eid) ON UPDATE CASCADE,
FOREIGN KEY (room, floor) REFERENCES Meeting_Rooms(room, floor) ON UPDATE CASCADE 
); 

CREATE TABLE Updates (
date DATE,
current_cap INTEGER NOT NULL,
eid INTEGER,
room INTEGER,
floor INTEGER,
PRIMARY KEY (room, floor),
FOREIGN KEY (eid) REFERENCES Manager(eid) ON UPDATE CASCADE,
FOREIGN KEY (room, floor) REFERENCES Meeting_Rooms(room, floor) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE Joins (
	eid INTEGER,
	time TIME,
	date DATE,
	room INTEGER,
	floor INTEGER,
	PRIMARY KEY(eid, time, date, room, floor),
FOREIGN KEY (time, date, room, floor) REFERENCES Sessions(time, date, room, floor) ON UPDATE CASCADE ON DELETE CASCADE,
FOREIGN KEY (eid) REFERENCES Employees (eid) ON UPDATE CASCADE
);

CREATE TABLE Health_declaration (
date DATE,
eid INTEGER, 
temp FLOAT, 
fever BOOLEAN,
PRIMARY KEY (eid, date),  
FOREIGN KEY (eid) REFERENCES Employees(eid) ON UPDATE CASCADE
);



