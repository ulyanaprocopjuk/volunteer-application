from pydantic import BaseModel


class GeocodingSuggestionResponse(BaseModel):
    id: str
    title: str
    subtitle: str
    fullAddress: str
    latitude: float
    longitude: float
    precision: str
    country: str
    city: str


class ForwardGeocodeResponse(BaseModel):
    query: str
    country: str | None = None
    items: list[GeocodingSuggestionResponse]


class ReverseGeocodeResponse(BaseModel):
    latitude: float
    longitude: float
    item: GeocodingSuggestionResponse
