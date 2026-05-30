from pydantic import BaseModel, ConfigDict, Field


class InspectionImageResponse(BaseModel):
    angle: int
    label: str
    url: str

    model_config = ConfigDict(extra="ignore")


class InspectionResponse(BaseModel):
    id: str
    container_number: str
    booking_number: str
    truck_number: str
    worker_name: str
    port_name: str
    notes: str
    status: str
    created_at: str
    updated_at: str
    image_urls: list[str]
    images: list[InspectionImageResponse] = Field(default_factory=list)

    model_config = ConfigDict(extra="ignore")


class ExportEmailResponse(BaseModel):
    status: str
    message: str
    report_url: str
    email_sent: bool = False
    email_to: str | None = None
    filename: str | None = None


class ScanContainerIdResponse(BaseModel):
    container_number: str
