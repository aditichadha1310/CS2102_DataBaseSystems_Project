CREATE OR REPLACE PROCEDURE add_room(IN floor_number INTEGER, IN room_number INTEGER, IN room_capacity INTEGER, IN room_name TEXT, IN department_ID INTEGER) AS $$
	
	INSERT INTO Meeting_rooms(room, floor, rname, did) 
	VALUES(room_number, floor_number, room_name, department_ID);
	INSERT INTO Updates(date, current_cap, eid, room, floor) 
	VALUES (CURRENT_DATE, room_capacity, NULL, room_number, floor_number);

$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE add_employee(IN ename TEXT, IN contact_1 INTEGER, IN contact_2 INTEGER, IN contact_3 INTEGER, IN kind TEXT, IN dept_id INTEGER) AS $$
	DECLARE 
		eid INT := FLOOR(RANDOM()*(2147483647-1+1))+1;
		email TEXT := split_part(ename, ' ', 1) || eid || '@example.com';
	BEGIN
		INSERT INTO Employees VALUES(eid, ename, email, NULL, dept_id);		
		INSERT INTO Contacts VALUES(eid, contact_1, contact_2, contact_3);		
		IF kind LIKE 'Junior' OR kind like 'junior' THEN 
			INSERT INTO Junior VALUES(eid, ename, email, NULL, dept_id); 
		ELSIF kind LIKE 'Senior' OR kind like 'senior' THEN 
			INSERT INTO Booker VALUES(eid, ename, email, NULL, dept_id);
			INSERT INTO Senior VALUES(eid, ename, email, NULL, dept_id);
		ELSIF kind LIKE 'Manager' OR kind like 'manager' THEN 
			INSERT INTO Booker VALUES(eid, ename, email, NULL, dept_id);
			INSERT INTO Manager VALUES(eid, ename, email, NULL, dept_id); 
		END IF;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION view_future_meeting(IN start_date DATE, IN emp_id INTEGER) RETURNS 
TABLE(floor_number INT, room_number INT, date DATE, start_time TIME) AS $$
BEGIN 
  RETURN QUERY select output_floor_number, output_room_number, session_date, time from (
	select sub.floor as output_floor_number, sub.room as output_room_number, sub.date as session_date, sub.time as time, get_is_approved(sessions.approver_eid) as var from (
	(select * from joins where eid=emp_id) as sub 
	join sessions on sub.date = sessions.date and sub.time = sessions.time) 
	where sub.date >= start_date
	group by sub.eid, sub.date, sub.time, sub.floor, sub.room, get_is_approved(sessions.approver_eid)
	order by sub.date, sub.time) as foo2 
	where var = 'true';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_is_approved(IN approver_eid INTEGER) RETURNS TABLE(val TEXT) AS $$ 

	DECLARE 
		val TEXT := 'false';
	BEGIN
		IF approver_eid IS NOT NULL THEN val:= 'true';
		ELSE val:= 'false';
		END IF;
	RETURN QUERY SELECT val;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION view_manager_report(IN start_date DATE, IN manager_query_eid INTEGER) RETURNS 
TABLE(floor_no INTEGER, room_no INTEGER, meeting_date DATE, start_hour TIME, booker_eid INTEGER) AS $$
BEGIN
	IF manager_query_eid NOT IN (SELECT eid from Booker) THEN
		RETURN;
	ELSE 
		RETURN QUERY SELECT * FROM (SELECT sub3.floor, sub3.room, sub3.date, sub3.time, sub3.eid FROM (
			SELECT e.eid, e.did FROM Employees e WHERE e.eid=manager_query_eid) as sub1 JOIN (
				SELECT sub2.floor, sub2.room, sub2.date, sub2.time, sub2.eid, m.did FROM (
					(SELECT * FROM Sessions WHERE approver_eid IS NULL) as sub2 JOIN 
					Meeting_rooms m ON sub2.room = m.room AND sub2.floor = m.floor)) as sub3 ON sub1.did = sub3.did
		WHERE date >= start_date
		ORDER BY date, time) as foo_final;
	END IF;
END;
$$ LANGUAGE plpgsql;

-- select * from view_manager_report('2021-10-28', 19);

CREATE OR REPLACE FUNCTION view_booking_report (start_date DATE, employee_id INT) RETURNS 
TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time TIME, booking_status TEXT) AS $$

	SELECT s.floor, s.room, s.date, s.time, get_is_approved(s.approver_eid)
	FROM Sessions s
	WHERE s.date >= start_date AND s.eid = employee_id
	Order By s.date, s.time;

$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE add_department(dept_id INT, dept_name TEXT) AS $$

	INSERT INTO Departments VALUES (dept_id, dept_name);

$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION check_can_remove_dept() RETURNS TRIGGER AS $$
	BEGIN 
		IF OLD.did IN (SELECT DISTINCT did from Employees) THEN
			RAISE NOTICE 'You cannot delete a department which still has employees';
			RETURN NULL;
		ELSIF OLD.did IN (SELECT DISTINCT did from Meeting_rooms) THEN
			RAISE EXCEPTION 'You cannot delete a department which still has meeting rooms';
			RETURN NULL;
		ELSE
			RETURN OLD;
		END IF;
	END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS can_delete_dept on Departments;

CREATE TRIGGER can_delete_dept
BEFORE DELETE ON Departments 
FOR EACH ROW EXECUTE FUNCTION check_can_remove_dept();

CREATE OR REPLACE PROCEDURE remove_department(dept_id INT) AS $$
	BEGIN 
			DELETE FROM Departments d WHERE d.did = dept_id;
	END;

$$ LANGUAGE plpgsql;

-- call remove_department(905);

CREATE OR REPLACE FUNCTION change_capacity(Change_date DATE, New_Cap INTEGER, emp_eid INTEGER, FLOOR_NUM INTEGER, ROOM_NUM INTEGER) RETURNS VOID AS $$  
	
	BEGIN
		UPDATE Updates SET eid = emp_eid, current_cap = New_Cap, date = change_date WHERE (floor = FLOOR_NUM AND room = ROOM_NUM);
		DELETE FROM SESSIONS WHERE (floor = Floor_num AND room= room_num AND num_participants > new_cap);
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION search_room_alternate (capacity INTEGER, meeting_date DATE, start_hour TIME, end_hour TIME) 
    RETURNS TABLE(floor_num INTEGER, room_num INTEGER, department_id INTEGER, room_cap INTEGER) AS $$
    BEGIN 
		RETURN QUERY
			WITH room AS(
				SELECT u.floor,u.room FROM Updates u INNER JOIN meeting_Rooms m ON u.floor = m.floor AND u.room = m.room WHERE current_cap >= capacity
				EXCEPT
				SELECT s.floor, s.room  FROM Sessions s WHERE s.date = meeting_date AND time < end_hour AND time >= start_hour ORDER BY floor,room )
			SELECT r.floor, r.room, m.did, u.current_cap FROM room r INNER JOIN meeting_Rooms m ON r.floor = m.floor AND r.room = m.room INNER JOIN Updates u ON u.floor = m.floor AND u.room = m.room;
	END
	$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_employee_working(IN emp_eid INTEGER, IN start_date DATE) RETURNS TABLE(val TEXT) AS $$
	DECLARE 
		val TEXT := 'false';
	BEGIN
		IF ((SELECT resigned_date FROM Employees e where e.eid = emp_eid) IS NOT NULL) AND ((SELECT resigned_date FROM Employees e where e.eid = emp_eid) < start_date) THEN 
			val := 'false';
		ELSE
			val := 'true';
		END IF;
	RETURN QUERY SELECT val;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION non_compliance(IN start_date DATE, IN end_date DATE) RETURNS TABLE(eid INTEGER, num_days BIGINT) AS $$
	DECLARE 
		diff INT := DATE_PART('day', end_date::timestamp - start_date::timestamp) + 1;
	BEGIN
		DROP TABLE IF EXISTS product_totals;
		CREATE TEMP TABLE product_totals(emp_id INTEGER, num_default BIGINT);
		INSERT INTO product_totals 
		SELECT * FROM helper(start_date, end_date);
		INSERT INTO product_totals
		SELECT * FROM zero_declarations(start_date, end_date);
		RETURN QUERY SELECT * FROM product_totals
		WHERE num_default > 0 AND (SELECT * FROM is_employee_working(emp_id, start_date)) LIKE 'true'
		ORDER BY num_default DESC;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION helper(IN start_date DATE, IN end_date DATE) returns TABLE(eid INTEGER, num_days BIGINT) AS $$
	DECLARE 
		diff INT := DATE_PART('day', end_date::timestamp - start_date::timestamp) + 1;
	BEGIN RETURN QUERY SELECT * FROM (
				SELECT Health_declaration.eid,  diff - NULLIF(count(*),0) as num_default FROM Health_declaration
				WHERE date >= start_date and date <= end_date
				GROUP BY Health_declaration.eid
				ORDER BY num_default DESC) AS foo;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION zero_declarations(IN start_date DATE, IN end_date DATE) returns TABLE(eid INTEGER, num_days BIGINT) AS $$
	DECLARE 
		diff BIGINT := DATE_PART('day', end_date::timestamp - start_date::timestamp) + 1;
	BEGIN RETURN QUERY SELECT * FROM (
				SELECT DISTINCT Employees.eid,  diff as num_default FROM Employees
				WHERE Employees.eid NOT IN (SELECT foo3.eid FROM (SELECT Health_declaration.eid,  count(*) as num_default FROM Health_declaration
				WHERE date >= start_date and date <= end_date GROUP BY Health_declaration.eid) AS foo3)
				GROUP BY Employees.eid
				ORDER BY num_default DESC) AS foo;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_capacity_and_health() RETURNS TRIGGER AS $$
	BEGIN
		IF (SELECT s.num_participants FROM Sessions s WHERE s.floor = NEW.floor AND s.room = NEW.room AND s.date = NEW.date AND s.time = NEW.time) >= 
			(SELECT m.current_cap FROM Updates m WHERE m.floor = NEW.floor AND m.room = NEW.room) THEN 
			RAISE NOTICE 'The meeting is full.';
			RETURN NULL;
		ELSIF NEW.eid IN (SELECT e.eid FROM Employees e WHERE e.resigned_date IS NOT NULL) AND (NEW.date > (SELECT e.resigned_date FROM Employees e WHERE e.eid = NEW.eid)) THEN
			RAISE NOTICE 'Employees who are no longer employed cannot join meetings';
			RETURN NULL;
		ELSIF NEW.eid NOT IN (SELECT health.eid FROM Health_declaration health WHERE health.eid = NEW.eid AND health.date = NEW.date) THEN
			RAISE NOTICE 'Employees who have not declared their temperature cannot join meetings';
			RETURN NULL;
		ELSE 
			RETURN NEW;
		END IF;
	END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS lessThanCapacityAndNotSick on Joins;

CREATE TRIGGER lessThanCapacityAndNotSick
BEFORE INSERT ON Joins 
FOR EACH ROW EXECUTE FUNCTION check_capacity_and_health();

CREATE OR REPLACE PROCEDURE join_meeting(floor_no INTEGER, room_no INTEGER, meeting_date DATE, start_time TIME, end_time TIME, emp_id INTEGER) AS $$
	DECLARE 
		start_time_as_time_for_loop TIME;
	BEGIN 
		IF (SELECT health.temp FROM health_declaration health WHERE health.eid = emp_id AND meeting_date = health.date) > 37.5 THEN
			RAISE INFO 'Employees who have fever cannot be added to meeting';
			RETURN;
		ELSE 
			WHILE start_time <> end_time LOOP
				IF (emp_id, meeting_date, start_time) IN (SELECT j.eid, j.date, j.time FROM joins j WHERE j.eid = emp_id and j.date = meeting_date and j.time =  start_time) THEN 
					RAISE INFO 'Employee is already in another meeting at the same time. Please remove from the other meeting before adding to this one';
				ELSIF (meeting_date, start_time, floor_no, room_no) NOT IN (SELECT s.date, s.time, s.floor, s.room FROM Sessions s WHERE s.date = meeting_date AND s.time =  start_time) THEN
					RAISE INFO 'Meeting does not exist yet. Please create a meeting and then add employee';
				ELSE 
					IF (SELECT s.approver_eid FROM Sessions s 
						where s.date = meeting_date and s.time = start_time 
						and s.room = room_no and s.floor = floor_no) IS NOT NULL THEN
						RAISE EXCEPTION 'Room is already approved';
						RETURN;
					ELSE
						INSERT INTO Joins VALUES(emp_id, start_time, meeting_date, room_no, floor_no);
						UPDATE Sessions s SET num_participants = num_participants + 1 WHERE s.date = meeting_date and s.time = start_time and s.room = room_no and s.floor = floor_no;
					END IF;
				END IF;
				start_time := start_time + interval '1 hour';
			END LOOP;
		END IF;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION canBook() RETURNS TRIGGER AS $$
	BEGIN
		IF NEW.eid IN (SELECT eid from Junior) THEN
			RAISE NOTICE 'Juniors cannot book meeting';
			RETURN NULL;
		ELSIF (NEW.room, NEW.floor) NOT IN (SELECT m.room, m.floor from meeting_rooms m) THEN
			RAISE NOTICE 'Meeting room specified does not exist';
		ELSE 
			RETURN NEW;
		END IF;
	END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS isAllowedToBook on Sessions;

CREATE TRIGGER isAllowedToBook
BEFORE INSERT ON Sessions 
FOR EACH ROW EXECUTE FUNCTION canBook();

CREATE OR REPLACE PROCEDURE book_room(IN floor_no INT, IN room_no INT, IN meeting_date DATE, IN start_time TIME, IN end_time TIME, IN emp_id INTEGER) AS $$
	BEGIN
		IF (SELECT e.resigned_date FROM Employees e WHERE e.eid=emp_id) IS NOT NULL AND (SELECT e.resigned_date FROM Employees e WHERE e.eid=emp_id) < meeting_date THEN
			RAISE EXCEPTION 'You need to be employed in order to book meeting'; 
		ELSE
			WHILE start_time <> end_time LOOP
				IF (start_time, floor_no, room_no) IN (SELECT s.time, s.floor, s.room FROM Sessions s WHERE s.time = start_time and s.floor = floor_no and s.room = room_no) THEN
					RAISE INFO 'There is already a session booked for that particular time slot';
				ELSIF emp_id NOT IN (SELECT h.eid from Health_declaration h WHERE h.date = meeting_date) THEN
					RAISE EXCEPTION 'You must declare temperature before booking a room ';
				ELSIF (SELECT h.temp FROM Health_declaration h WHERE h.eid = emp_id and h.date = meeting_date) > 37.5 THEN
					RAISE EXCEPTION 'You cannot book a room while you are having a fever';
				ELSE 
					INSERT INTO Sessions VALUES(start_time, meeting_date, room_no, floor_no, emp_id, NULL, 1);
					INSERT INTO Joins VALUES(emp_id, start_time, meeting_date, room_no, floor_no);
				END IF;
				start_time := start_time + interval '1 hour';
			END LOOP;
		END IF;
	END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE unbook_room(Floor_Num INTEGER, Room_Num INTEGER, meeting_date DATE, begin_time TIME, end_time TIME, Emp_id INTEGER) AS $$   
	BEGIN
		while begin_time <> end_time loop
			IF (Room_Num, Floor_Num) NOT IN (SELECT m.room, m.floor from meeting_rooms m) THEN
				RAISE EXCEPTION 'Meeting room specified does not exist';
			ELSIF ((Select DISTINCT eid FROM Sessions WHERE time = begin_time and room=room_num AND floor =Floor_num AND date =meeting_date) = Emp_id)
			THEN
					DELETE FROM JOINS j WHERE j.Room = room_Num AND j.floor = Floor_Num AND begin_time = j.time AND j.date = meeting_date;  
					DELETE FROM SESSIONS s WHERE s.time = begin_time AND s.date = meeting_date AND s.floor= Floor_num AND s.room =Room_num;
			ELSE
				RAISE INFO  'There is no booking done by the employee id provided'; 
			END IF;
			begin_time := begin_time + interval '1 hour';
		end loop; 
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE change_capacity(FLOOR_NUM INTEGER, ROOM_NUM INTEGER, New_Cap INTEGER, Change_date DATE, Emp_ID INTEGER)
	AS $$  
	DECLARE 
		time_variable_start TIME := '00:00:00';
		time_variable_end TIME := '23:00:00';
	BEGIN
		IF (SELECT m.did FROM meeting_rooms m WHERE m.floor = FLOOR_NUM AND m.room = ROOM_NUM) IN (SELECT e.did from Employees e, Manager ma WHERE ma.eid = Emp_id AND e.eid = ma.eid) 
			THEN
			UPDATE Updates SET eid = Emp_ID, current_cap = New_cap, date = Change_date  WHERE (floor = FLOOR_NUM AND room = ROOM_NUM);
			while time_variable_start < time_variable_end loop	
				IF (SELECT s.num_participants FROM Sessions s where s.date > change_date and s.room = room_num and s.floor = floor_num and s.time = time_variable_start) > 
				(SELECT u.current_cap from updates u where u.room = room_num and u.floor = floor_num) THEN
					DELETE FROM SESSIONS s WHERE (s.floor = Floor_num AND s.room = room_num AND s.num_participants > new_cap and s.time = time_variable_start);
					DELETE FROM JOINS j WHERE (j.room = room_num and j.floor = floor_num and j.time = time_variable_start and j.date > change_date);
				END IF;
				SELECT time_variable_start + interval '1 hour' INTO time_variable_start;
			end loop;
		ELSE
			RAISE EXCEPTION 'Only managers belonging to the same department as the meeting room can change its capacity';
		END IF;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE approve_meeting(begin_time TIME, end_time TIME, meeting_date DATE, Floor_Num INTEGER, Room_Num INTEGER, approvers_eid INTEGER) AS $$   
	BEGIN
		IF (approvers_eid IN (SELECT eid from Manager)) AND (SELECT m.did From Manager m where m.eid = approvers_eid) = (SELECT e.did FROM employees e WHERE eid IN (SELECT eid FROM SESSIONS s WHERE s.time = begin_time AND s.date = meeting_date AND s.floor= Floor_num AND s.room = Room_Num))
		THEN 
			while begin_time <> end_time loop
				UPDATE Sessions SET approver_eid = approvers_eid WHERE (time = begin_time AND date = meeting_date AND floor= Floor_num AND room = Room_Num);
				begin_time:= begin_time + interval '1 hour';
			end loop;
		ELSE
			RAISE EXCEPTION 'The approver of the meeting should belong to the same department as the booker.'; 
		END IF;
	END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_capacity on joins;

CREATE TRIGGER update_capacity
AFTER DELETE ON joins
FOR EACH ROW EXECUTE FUNCTION update_meeting_capacity();

CREATE OR REPLACE FUNCTION update_meeting_capacity() RETURNS TRIGGER AS $$
	BEGIN 
		UPDATE Sessions SET num_participants = num_participants - 1 WHERE 
		date = OLD.date AND time = OLD.time and room = OLD.room AND floor = OLD.floor;
		RETURN OLD;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE leave_meeting(begin_time TIME, end_time TIME, meeting_date DATE, Floor_Num INTEGER, Room_Num INTEGER, Emp_id INTEGER) AS $$   
	BEGIN
		IF (Select s.approver_eid FROM Sessions s WHERE s.room=room_num AND s.floor =Floor_num AND s.date =meeting_date and s.time = begin_time) <> NULL THEN
			RAISE EXCEPTION 'You cannot leave a meeting which is already approved';
		ELSE
			while begin_time <> end_time loop	
				IF (Select s.eid FROM Sessions s WHERE s.room=room_num AND s.floor =Floor_num AND s.date =meeting_date and s.time = begin_time) = emp_id THEN
					DELETE FROM JOINS j WHERE j.Room = room_Num AND j.floor = Floor_Num AND begin_time = j.time AND j.date = meeting_date;  
					DELETE FROM SESSIONS s WHERE s.time = begin_time AND s.date = meeting_date AND s.floor= Floor_num AND s.room =Room_num;
				ELSIF (Emp_id IN (SELECT eid FROM JOINS WHERE time = begin_time AND date = meeting_date AND floor= Floor_num AND room = Room_Num )) THEN 
					DELETE FROM JOINS j WHERE j.eid = Emp_id AND j.Room = room_Num AND j.floor = Floor_Num AND begin_time = j.time AND j.date = meeting_date;  
				ELSE
					RAISE INFO 'The employee is not scheduled to attend this meeting.'; 
				END IF;
				begin_time := begin_time + interval '1 hour';
			end loop;
		END IF;	
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE remove_employee(Employee_id INTEGER, resign_date DATE) AS $$
	DECLARE
		send_room INT;
		send_floor INT;
		send_date DATE;
	BEGIN 
		IF (Employee_id IN (SELECT eid FROM Employees))
		THEN 
			UPDATE Employees SET resigned_date = resign_date WHERE eid = Employee_id; 
 			DELETE FROM Sessions WHERE eid = Employee_id AND (date > resign_date);
			UPDATE Sessions SET approver_eid = NULL WHERE eid = employee_id and date > resign_date;
			SELECT j.room FROM joins j where j.eid = Employee_id AND j.date >= resign_date INTO send_room;
			SELECT j.floor FROM joins j where j.eid = Employee_id AND j.date >= resign_date INTO send_floor;
			SELECT j.date FROM joins j where j.eid = Employee_id AND j.date >= resign_date INTO send_date;
			PERFORM update_Sessions(send_room, send_floor, send_date);
			DELETE FROM JOINS WHERE eid = Employee_id AND (date > resign_date);	
		ELSE
			RAISE EXCEPTION 'The employee does not exist in the database'; 
		END IF;
	END;
$$ LANGUAGE plpgsql; 

CREATE OR REPLACE FUNCTION update_Sessions(Room_num INTEGER, floor_num INTEGER, meeting_date date) RETURNS VOID AS $$
	BEGIN
		UPDATE Sessions SET num_participants = num_participants-1 WHERE room=room_num AND floor=floor_num AND date = meeting_date;		
	END;
$$ LANGUAGE plpgsql; 

-- call remove_employee( 1989912859, '2021-10-31');

CREATE OR REPLACE FUNCTION search_room(IN capacity INT, IN meeting_date DATE, IN start_hour TIME, IN end_hour TIME) RETURNS TABLE(floor_num INT, room_no INT, did INT, return_capacity INT) AS $$
	BEGIN
		RETURN QUERY SELECT m.room, m.floor, m.did, u.current_cap FROM meeting_rooms m join updates u on m.room = u.room and m.floor = u.floor
		WHERE u.current_cap >= capacity AND NOT EXISTS (SELECT 1 FROM Sessions s WHERE (s.time < end_hour AND s.time >= start_hour) 
		AND s.date = meeting_date AND s.room = m.room AND s.floor = m.floor)
		ORDER BY current_cap ASC;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE declare_health(IN declare_date DATE, IN Emp_id INTEGER, IN temperature FLOAT) AS $$
	DECLARE 
		fever BOOLEAN := FALSE;
	BEGIN
		IF (temperature > 37.5) THEN
			fever := TRUE;	
		END IF;
		INSERT INTO health_declaration VALUES (declare_date, Emp_id, temperature, fever) ;
	END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_if_sick() RETURNS TRIGGER AS $$ 
	BEGIN
		IF NEW.Fever = TRUE THEN
			RAISE INFO 'This employee has fever and you must do contact tracing. The ID of the employee is % and the date is %', NEW.eid, NEW.date;
		END IF;
		RETURN NEW;
	END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS has_fever on health_declaration;

CREATE TRIGGER temp_too_high
BEFORE INSERT ON health_declaration
FOR EACH ROW EXECUTE FUNCTION check_if_sick();

CREATE OR REPLACE FUNCTION contact_tracing(emp_id INT, fever_date DATE) RETURNS TABLE (return_eid INT) AS $$
	BEGIN
	RETURN QUERY SELECT DISTINCT join2.eid AS eid FROM joins join1, joins join2 WHERE join1.eid = emp_id AND join2.eid <> emp_id
		AND join1.time = join2.time AND join2.date = join1.date AND join2.room = join1.room AND join2.floor = join1.floor AND join1.date > fever_date -3;

	DELETE FROM sessions s WHERE (s.eid IN (SELECT DISTINCT join2.eid AS eid FROM joins join1, joins join2 WHERE join1.eid = emp_id
		AND join1.time = join2.time AND join2.date = join1.date AND join2.room = join1.room AND join2.floor = join1.floor AND join1.date > fever_date -3) 
		AND s.date >= fever_date AND s.date <= fever_date + 7);
	
	DELETE FROM joins j WHERE (j.eid = emp_id AND j.date >= fever_date AND j.date <= fever_date + 7); 
	END;
$$
LANGUAGE plpgsql;



	



		