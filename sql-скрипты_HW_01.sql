--СОЗДАНИЕ ТАБЛИЦ
create table customers (
    customer_id integer,
    first_name varchar(50),
    last_name varchar(50),
    gender varchar(20),
    dob date,
    job_title varchar(100),
    job_industry_category varchar(100),
    wealth_segment varchar(50),
    deceased_indicator boolean,
    owns_car boolean,
    address varchar(200),
    postcode integer,
    state varchar(10),
    country varchar(50),
    property_valuation numeric(5,2)
);

create table products (
    product_id integer,
    brand varchar(50),
    product_line varchar(50),
    product_class varchar(50),
    product_size varchar(20),
    list_price numeric(12,2),
    standard_cost numeric(12,2)
);

create table orders (
    order_id integer,
    customer_id integer,
    order_date timestamp,
    online_order boolean,
    order_status varchar(30)
);

create table order_items (
    order_item_id integer,
    order_id integer,
    product_id integer,
    quantity integer,
    item_list_price_at_sale numeric(12,2),
    item_standard_cost_at_sale numeric(12,2)
);



--ПРОВЕРКА ДУБЛЕЙ
select customer_id 
	  ,count(*)
from customers
group by customer_id 
having count(*) > 1
;

select product_id 
	  ,count(*)
from products
group by product_id 
having count(*) > 1
;

select order_id 
	  ,count(*)
from orders
group by order_id 
having count(*) > 1
;

select order_item_id 
	  ,count(*)
from order_items
group by order_item_id 
having count(*) > 1
;



-- НАЗНАЧЕНИЕ КЛЮЧЕЙ
alter table customers add constraint pk_customers primary  key (customer_id);

alter table products add constraint pk_products primary key (product_id);

alter table orders add constraint pk_orders primary key (order_id);

alter table order_items add constraint pk_order_items primary key (order_item_id);

alter table orders add constraint fk_orders_customer
    foreign key (customer_id) references customers (customer_id);

alter table order_items add constraint fk_items_order
    foreign key (order_id) references orders (order_id);

alter table order_items add constraint fk_items_product
    foreign key (product_id) references products (product_id);




--ВЫПОЛНЕНИЕ ЗАПРОСОВ 
--1. Выведите id продукта и среднюю цену продажи (item_list_price_at_sale) для 5 продуктов с самой высокой средней ценой продажи.
select product_id
	  ,avg(item_list_price_at_sale) as avg_price
from order_items 
group by product_id 
order by avg_price 
limit 5
;

--2. Рассчитайте общую стоимость заказа (item_list_price_at_sale * quantity) для каждого бренда продукта.
select p.brand 
	  ,sum(oi.item_list_price_at_sale * oi.quantity) as total
from order_items oi  
join products p on p.product_id = oi.product_id 
group by p.brand 
;

--3. Подсчитайте количество заказов за каждый месяц для каждого года. То есть необходимо вывести год, месяц и количество заказов.
select extract(year from order_date)  as order_year
	  ,extract(month from order_date) as order_month
	  ,count(*)
from orders
group by order_year
        ,order_month
order by order_year
        ,order_month
;

--4. Для каждой продуктовой линейки (product_line) найдите продукт с самой высокой стандартной стоимостью (standard_cost). Выведите id продукта, линейку продукта и стандартную стоимость.
select product_id 
 	  ,product_line 
 	  ,standard_cost 
from (
	select product_id 
		  ,product_line 
		  ,standard_cost 
		  ,rank() over(partition by product_line order by standard_cost desc) as rnk
	from products
)
where rnk = 1
order by product_line
;

--5. Подсчитайте количество заказов и общую стоимость заказов для каждого статуса заказа (order_status). Общую стоимость заказа необходимо рассчитать как цену продукта на момент продажи, умноженную на количество единиц продукта в заказе.
select o.order_status 
	  ,count(distinct o.order_id)
	  ,sum(oi.item_list_price_at_sale * oi.quantity) 
from orders o 
join order_items oi on oi.order_id = o.order_id 
group by o.order_status 
;

--6. Найдите клиентов, у которых нет ни одного заказа. Выведите id клиента, фамилию и имя.
select c.customer_id 
	  ,c.last_name 
	  ,c.first_name 
from customers c 
left join orders o on o.customer_id = c.customer_id 
where o.order_id is null
;

--7. Для каждого штата найдите клиента с самой высокой и самой низкой оценкой стоимости имущества (property_valuation). Выведите штат, оценку стоимости имущества, фамилию и имя клиента.
select state
	  ,property_valuation
	  ,last_name
	  ,first_name
from (
	select state
		  ,property_valuation 
		  ,last_name 
		  ,first_name 
		  ,rank() over(partition by state order by property_valuation desc) as max_proper
		  ,rank() over(partition by state order by property_valuation asc) as min_proper
	from customers
)
where min_proper = 1 or max_proper = 1
;

--8. Найдите клиентов, которые покупали продукты только из одной продуктовой линейки (product_line). Выведите id клиента, линейку продукта и количество заказов.
select customer_id 
	  ,product_line 
	  ,order_cnt 
from (
	select o.customer_id
	      ,p.product_line 
	      ,count(distinct o.order_id) as order_cnt
	      ,count(*) over(partition by o.customer_id) as lines_cnt
	from orders o 
	join order_items oi on oi.order_id = o.order_id 
	join products p on p.product_id = oi.product_id 
	group by o.customer_id 
	        ,p.product_line 
) 
where lines_cnt = 1
;

--9. Для каждой категории продуктов рассчитайте процент отмененных заказов (order_status = 'Cancelled').
select p.product_class 
      ,count(distinct o.order_id) as order_total
      ,count(distinct case when o.order_status = 'Cancelled' then o.order_id end) as order_cancelled
      ,round(count(distinct case when o.order_status = 'Cancelled' then o.order_id end) * 100.0 / count(distinct o.order_id), 2) as order_cancelled_percent
from orders o
join order_items oi on oi.order_id = o.order_id 
join products p on p.product_id = oi.product_id 
group by p.product_class 
;

--10.	Разделите клиентов на сегменты на основе количества заказов и подсчитайте количество клиентов в каждом сегменте:
--			сегмент High, если количество заказов больше 10;
--			сегмент Medium, если количество заказов от 5 до 10;
--			иначе сегмент Low.
select segment 
      ,count(*) as cnt
from (
	select c.customer_id
	      ,case when count(o.order_id) > 10 then 'High'
	      		when count(o.order_id) >= 5 then 'Medium'
	      		else 'Low' end as segment
	from customers c 
	left join orders o on o.customer_id = c.customer_id 
	group by c.customer_id 
)
group by segment 
;

--11. Для всех клиентов выведите имена, фамилии, профессии, а также длительность максимального интервала (в днях) между двумя последовательными заказами. Необходимо исключить клиентов, у которых только один заказ или меньше.
with order_interval as (
	select customer_id
		  ,order_date - lag(order_date) over(partition by customer_id order by order_date) as interval_days
	from orders
)
select c.customer_id  
      ,c.first_name 
      ,c.job_title 
      ,max(or_in.interval_days) as max_interval_days
from order_interval or_in
join customers c on c.customer_id = or_in.customer_id 
group by c.customer_id 
        ,c.first_name 
        ,c.last_name 
        ,c.job_title 
having count(*) >= 2
;



