from dataclasses import dataclass
import os
from fastapi import APIRouter, FastAPI, HTTPException

HOSTNAME = os.getenv('HOST', 'localhost')
PORT = os.getenv('PORT', '5000')
API_PREFIX = os.getenv('API_PREFIX')


@dataclass
class Employee:
    id: int
    LastName: str
    FirstName: str
    Title: str
    ReportsTo: str
    BirthDate: str
    HireDate: str
    Address: str
    City: str
    State: str
    Country: str
    PostalCode: str
    Phone: str
    Fax: str
    Email: str


employees = [
    Employee(1, "Adams", "Andrew", "Manager", "",
             "1962-02-18 00:00:00", "2002-08-14 00:00:00", "11120 Jasper Ave NW", "Edmonton",
             "AB", "Canada", "T5K 2N1", "+1 (780) 428-9482",
             "+1 (780) 428-3457", "andrew@corp.com"),
    Employee(2, "Edwards", "Nancy", "Sales Representative",
             "Andrew Adams", "1958-12-08 00:00:00", "2003-05-01 00:00:00", "825 8 Ave SW",
             "Calgary", "AB", "Canada", "T2P 2T3",
             "+1 (403) 262-3443", "+1 (403) 262-3322", "nancy@corp.com"),
    Employee(3, "Peacock", "Jane", "Sales Representative", "Andrew Adams",
             "1973-08-29 00:00:00", "2002-04-01 00:00:00", "4110 Old Redmond Rd", "Redmond",
             "WA", "USA", "98052", "+1 (206) 555-8122", "+1 (206) 555-2174", "jane@corp.com"),
    Employee(4, "Park", "Margaret", "Sales Representative", "Andrew Adams", "1947-09-19 00:00:00",
             "2003-05-03 00:00:00", "14 Garrett Hill", "London", "", "UK", "SW1 8JR", "+44 20 7877 2041",
             "+44 20 7877 2042", "margaret@corp.com"),
    Employee(5, "Johnson", "Steve", "Sales Representative", "Andrew Adams", "1965-03-03 00:00:00",
             "2003-10-17 00:00:00", "627 Broadway", "New York", "NY", "USA", "10012-2612",
             "+1 (212) 221-3546", "+1 (212) 221-4679", "steve@corp.com"),
    Employee(6, "Mitchell", "Michael", "IT Manager", "Andrew Adams", "1973-07-01 00:00:00",
             "2003-10-17 00:00:00", "5827 Bowness Road NW", "Calgary", "AB", "Canada", "T3B 0C5",
             "+1 (403) 246-9887", "+1 (403) 246-9898", "michael@corp.com"),
    Employee(7, "King", "Robert", "IT Staff", "Michael Mitchell", "1960-05-29 00:00:00",
             "2004-01-02 00:00:00", "590 Columbia Boulevard West", "Lethbridge", "AB", "Canada",
             "T1K 5N8", "+1 (403) 456-9986", "+1 (403) 456-8485", "robert@corp.com"),
    Employee(8, "Callahan", "Laura", "IT Staff", "Michael Mitchell", "1958-01-09 00:00:00",
             "2004-03-04 00:00:00", "923 7 ST NW", "Calgary", "AB", "Canada", "T2N 1M7",
             "+1 (403) 262-3443", "+1 (403) 262-6712", "laura@corp.com"),
    Employee(9, "Suyama", "Michael", "Sales Representative", "Andrew Adams", "1963-07-02 00:00:00",
             "2005-10-17 00:00:00", "Coventry House Miner Rd.", "London", "", "UK", "EC2 7JR",
             "+44 20 7877 2041", "+44 20 7877 2042", "suyama@corp.com"),
    Employee(10, "King", "Robert", "Sales Representative", "Andrew Adams", "1960-05-29 00:00:00",
                 "2004-01-02 00:00:00", "Edgeham Hollow Winchester Way", "London", "", "UK", "RG1 9SP",
             "+44 71 9288 2211", "+44 71 9288 2212", "robert.king@corp.com")
]


def setup_router(router: APIRouter) -> APIRouter:
    @router.get("/")
    async def root():
        return {"message": "Hello World"}

    @router.get("/employees")
    async def get_employees():
        return {'employees': employees}

    @router.get("/employees/{employee_id}")
    async def get_employee(employee_id: int):
        for employee in employees:
            if employee.id == employee_id:
                return {"data": [employee]}
        raise HTTPException(status_code=404, detail="Employee not found")

    return router


app = FastAPI()
router = APIRouter(prefix="/api")
router = setup_router(router)
app.include_router(router)
